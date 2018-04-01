package Plerd::Microformats2::Parser;

use Moose;
use MooseX::Types::URI qw(Uri);
use HTML::TreeBuilder::XPath;
use v5.10;
use Scalar::Util;
use JSON;
use DateTime::Format::ISO8601;

use Plerd::Microformats2::Item;

use Readonly;

has 'items' => (
    is => 'ro',
    traits => ['Array'],
    isa => 'ArrayRef[Plerd::Microformats2::Item]',
    default => sub { [] },
    lazy => 1,
    clearer => '_clear_items',
    handles => {
        all_top_level_items => 'elements',
        add_top_level_item => 'push',
        count_top_level_items => 'count',
        has_top_level_items => 'count',
    },
);

has 'rels' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    clearer => '_clear_rels',
    default => sub { {} },
);

has 'rel_urls' => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    clearer => '_clear_rel_urls',
    default => sub { {} },
);

has 'url_context' => (
    is => 'rw',
    isa => Uri,
    coerce => 1,
    lazy => 1,
    clearer => '_clear_url_context',
    default => sub { URI->new( 'http://example.com/' ) },
);

sub parse {
    my $self = shift;

    $self->_clear;

    my ( $html ) = @_;

    my $tree = HTML::TreeBuilder::XPath->new;
    $tree->ignore_unknown( 0 );
    $tree->no_space_compacting( 1 );
    $tree->ignore_ignorable_whitespace( 0 );

    $tree->parse( $html );

    if ( my $base_url = $tree->findvalue( './/base/@href' ) ) {
        $self->url_context( $base_url );
    }

    $self->analyze_element( $tree );

    return $self;
}

sub analyze_element {
    my $self = shift;
    my ( $element, $current_item ) = @_;

    return unless blessed( $element) && $element->isa( 'HTML::Element' );

    my $mf2_attrs = $self->_tease_out_mf2_attrs( $element );

    my $h_attrs = delete $mf2_attrs->{h};
    my $new_item;
    if ( $h_attrs->[0] ) {
        $new_item = Plerd::Microformats2::Item->new( {
            types => $h_attrs,
        } );
        unless ( $current_item ) {
            $self->add_top_level_item( $new_item );
        }
    }

    while (my ($mf2_type, $properties_ref ) = each( %$mf2_attrs ) ) {
        next unless $current_item;
        next unless @{ $properties_ref };
        if ( $mf2_type eq 'p' ) {
            unless ( $new_item ) {
                for my $property ( @$properties_ref ) {
                    my $vcp_fragments_ref =
                        $self->_seek_value_class_pattern( $element );
                    if ( @$vcp_fragments_ref ) {
                        $current_item->add_property(
                            $property,
                            join q{}, @$vcp_fragments_ref,
                        )
                    }
                    elsif ( my $alt = $element->findvalue( './@title|@value|@alt' ) ) {
                        $current_item->add_property( $property, $alt );
                    }
                    elsif ( my $text = _trim( $element->as_text ) ) {
                        $current_item->add_property( $property, $text );
                    }
                }
            }
        }
        elsif ( $mf2_type eq 'u' ) {
            unless ( $new_item ) {
                for my $property ( @$properties_ref ) {
                    if ( my $url = $self->_tease_out_url( $element ) ) {
                        $current_item->add_property( $property, $url );
                    }
                }
            }
        }
        elsif ( $mf2_type eq 'e' ) {
            for my $property ( @$properties_ref ) {
                my %e_data;
                for my $content_piece ( $element->content_list ) {
                    if ( ref $content_piece ) {
                        $e_data{html} .= $content_piece->as_HTML( '<>&', undef, {} );
                    }
                    else {
                        $e_data{html} .= $content_piece;
                    }
                }
                $e_data{ value } = _trim ($element->as_text);

                # The official tests specifically trim space-glyphs per se;
                # all other trailing whitespace stays. Shrug.
                $e_data{ html } =~ s/ +$//;

                $current_item->add_property( $property, \%e_data );
            }
        }
        elsif ( $mf2_type eq 'dt' ) {
            for my $property ( @$properties_ref ) {
                my $dt_string;
                my $vcp_fragments_ref =
                    $self->_seek_value_class_pattern( $element );
                if ( @$vcp_fragments_ref ) {
                    $dt_string = join q{}, @$vcp_fragments_ref;
                }
                elsif ( my $alt = $element->findvalue( './@datetime|@title|@value' ) ) {
                    $dt_string = $alt;
                }
                elsif ( my $text = $element->as_trimmed_text ) {
                    $dt_string = $text;
                }
                if ( defined $dt_string ) {
                    my $dt = DateTime::Format::ISO8601->new
                              ->parse_datetime( $dt_string );
                    # XXX Needs to check for & set timezone offset
                    my $format = '%Y-%m-%d %H:%M:%S';
                    $current_item->add_property(
                        $property,
                        $dt->strftime( $format ),
                    );
                }
            }
        }
    }

    if ( $new_item ) {
        for my $child_element ( $element->content_list ) {
            $self->analyze_element( $child_element, $new_item );
        }

        # Now that the new item's been recursively scanned, perform
        # some post-processing.
        # First, add any implied properties.
        for my $impliable_property (qw(name photo url)) {
            warn "Maybe $impliable_property?\n";
            unless ( $new_item->has_property( $impliable_property ) ) {
                warn "Yeah, let's check.\n";
                my $method = "_set_implied_$impliable_property";
                $self->$method( $new_item, $element );
            }
        }

        # Now add a "value" attribute to this new item, if appropriate,
        # according to the MF2 spec.
        if ( $mf2_attrs->{p}->[0] ) {
            $new_item->value( $new_item->get_properties('name')->[0] );
        }
        elsif ( $mf2_attrs->{u}->[0] ) {
            $new_item->value( $new_item->get_properties('url')->[0] );
        }

        # Put this onto the parent item's property-list, or its children-list,
        # depending on context.
        my $item_property;
        if (
            ( $item_property = $mf2_attrs->{p}->[0] )
            || ( $item_property = $mf2_attrs->{u}->[0] )
        ) {
            $current_item->add_property( $item_property, $new_item );
        }
        elsif ($current_item) {
            $current_item->add_child ( $new_item );
        }

    }
    else {
        for my $child_element ( $element->content_list ) {
            $self->analyze_element( $child_element, $current_item );
        }
    }
}

sub as_json {
    my $self = shift;

    my $data_for_json = {
        rels => $self->rels,
        'rel-urls' => $self->rel_urls,
        items => $self->items,
    };

    return JSON->new->convert_blessed->pretty->encode( $data_for_json );
}


sub _tease_out_mf2_attrs {
    my $self = shift;
    my ( $element ) = @_;

    my %mf2_attrs;
    foreach ( qw( h e u dt p ) ) {
        $mf2_attrs{ $_ } = [];
    }

    my $class_attr = $element->attr('class');
    if ( $class_attr ) {
        while ($class_attr =~ /\b(h|e|u|dt|p)-(\S+)/g ) {
            my $mf2_type = $1;
            my $mf2_attr = $2;

            push @{ $mf2_attrs{ $mf2_type } }, $mf2_attr;
        }
    }

    return \%mf2_attrs;
}

sub _tease_out_url {
    my $self = shift;
    my ( $element ) = @_;

    my $xpath;
    my $url;
    if ( $element->tag =~ /^(a|area|link)$/ ) {
        $xpath = './@href';
    }
    elsif ( $element->tag =~ /^(img|audio)$/ ) {
        $xpath = './@src';
    }
    elsif ( $element->tag eq 'video' ) {
        $xpath = '/@src|@poster';
    }
    elsif ( $element->tag eq 'object' ) {
        $xpath = '/@data';
    }

    if ( $xpath ) {
        $url = $element->findvalue( $xpath );
    }

    if ( defined $url ) {
        $url = URI->new_abs( $url, $self->url_context )->as_string;
    }
    else {
        $url = $element->as_trimmed_text;
    }

    return $url;
}

sub _set_implied_name {
    my $self = shift;
    my ( $item, $element ) = @_;

    return if $item->has_properties;

    my $xpath;
    my $name;
    my $kid;
    my $accept_if_empty = 1; # If true, then null-string names are okay.
    if ( $element->tag =~ /^(img|area)$/ ) {
        $xpath = './@alt';
    }
    elsif ( $element->tag eq 'abbr' ) {
        $xpath = './@title';
    }
    elsif (
        ( $kid = $self->_non_h_unique_child( $element, 'img' ) )
        || ( $kid = $self->_non_h_unique_child( $element, 'area' ) )
    ) {
        $xpath = './@alt';
        $accept_if_empty = 0;
    }
    elsif ( $kid = $self->_non_h_unique_child( $element, 'abbr' ) ) {
        $xpath = './@title';
        $accept_if_empty = 0;
    }
    elsif (
        ( $kid = $self->_non_h_unique_grandchild( $element, 'img' ) )
        || ( $kid = $self->_non_h_unique_grandchild( $element, 'area' ) )
    ) {
        $xpath = './@alt';
        $accept_if_empty = 0;
    }
    elsif ( $kid = $self->_non_h_unique_grandchild( $element, 'abbr' ) ) {
        $xpath = './@title';
        $accept_if_empty = 0;
    }

    my $foo = $kid || $element;

    warn "***I will check " . $foo->tag . " for $xpath.\n";

    if ( $xpath ) {
        my $element_to_check = $kid || $element;
        my $value = $element_to_check->findvalue( $xpath );
        warn "***I got $value!\n";
        if ( ( $value ne q{} ) || $accept_if_empty ) {
            $name = $value;
            warn "***Hell yeah let's assign it!\n";
        }
    }

    unless ( defined $name ) {
        $name = _trim( $element->as_text );
    }

    if ( length $name > 0 ) {
        warn "***Assigning $name!!!!!\n";
        $item->add_property( 'name', $name );
    }

}

sub _set_implied_photo {
    my $self = shift;
    my ( $item, $element ) = @_;

    my $xpath;
    my $url;
    my $kid;

    if ( $element->tag eq 'img' ) {
        $xpath = './@src';
    }
    elsif ( $element->tag eq 'object' ) {
        $xpath = './@data';
    }
    elsif ( $kid = $self->_non_h_unique_child( $element, 'img' ) ) {
        $xpath = './@src';
        $element = $kid;
    }
    elsif ( $kid = $self->_non_h_unique_child( $element, 'object' ) ) {
        $xpath = './@data';
        $element = $kid;
    }
    elsif ( $kid = $self->_non_h_unique_grandchild( $element, 'img' ) ) {
        $xpath = './@src';
        $element = $kid;
    }
    elsif ( $kid = $self->_non_h_unique_grandchild( $element, 'object' ) ) {
        $xpath = './@data';
        $element = $kid;
    }

    if ( $xpath ) {
        $url = $element->findvalue( $xpath );
    }

    if ( defined $url ) {
        $url = URI->new_abs( $url, $self->url_context )->as_string;
        $item->add_property( 'photo', $url );
    }

}

sub _set_implied_url {
    my $self = shift;
    my ( $item, $element ) = @_;

    my $xpath;
    my $url;

    my $kid;
    if ( $element->tag =~ /^(a|area)$/ ) {
        $xpath = './@href';
    }
    elsif (
        ( $kid = $self->_non_h_unique_child( $element, 'a' ) )
        || ( $kid = $self->_non_h_unique_child( $element, 'area' ) )
        || ( $kid = $self->_non_h_unique_grandchild( $element, 'a' ) )
        || ( $kid = $self->_non_h_unique_grandchild( $element, 'area' ) )
    ) {
        $xpath = './@href';
        $element = $kid;
    }

    if ( $xpath ) {
        $url = $element->findvalue( $xpath );
    }

    if ( defined $url ) {
        $url = URI->new_abs( $url, $self->url_context )->as_string;
        $item->add_property( 'url', $url );
    }

}

sub _non_h_unique_child {
    my $self = shift;
    my ( $element, $tag ) = @_;

    my @children = grep { (ref $_) && $_->tag eq $tag  } $element->content_list;

    if ( @children == 1 ) {
        my $mf2_attrs = $self->_tease_out_mf2_attrs( $children[0] );
        if (not ( $mf2_attrs->{h}->[0] ) ) {
            return $children[0];
        }
    }

    return;
}

sub _non_h_unique_grandchild {
    my $self = shift;
    my ( $element, $tag ) = @_;

    my @children = grep { ref $_ } $element->content_list;

    if ( @children == 1 ) {
        my $mf2_attrs = $self->_tease_out_mf2_attrs( $children[0] );
        if (not ( $mf2_attrs->{h}->[0] ) ) {
            return $self->_non_h_unique_child( $children[0], $tag );
        }
    }

    return;
}

sub _clear {
    my $self = shift;

    $self->_clear_items;
    $self->_clear_rels;
    $self->_clear_rel_urls;
    $self->_clear_url_context;
}

sub _seek_value_class_pattern {
    my $self = shift;

    my ( $element, $vcp_fragments_ref ) = @_;

    $vcp_fragments_ref ||= [];

    my $class = $element->attr( 'class' );
    if ( $class && $class =~ /\bvalue\b/ ) {
        my $html;
        for my $content_piece ( $element->content_list ) {
            if ( ref $content_piece ) {
                $html .= $content_piece->as_HTML;
            }
            else {
                $html .= $content_piece;
            }
        }
        push @$vcp_fragments_ref, $html;
    }
    else {
        for my $child_element ( grep { ref $_ } $element->content_list ) {
            $self->_seek_value_class_pattern(
                $child_element, $vcp_fragments_ref
            );
        }
    }

    return $vcp_fragments_ref;
}

sub _trim {
    my ($string) = @_;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

1;
