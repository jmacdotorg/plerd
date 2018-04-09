package Web::Microformats2::Document;
use Moose;
use JSON qw(decode_json);

has 'top_level_items' => (
    is => 'ro',
    traits => ['Array'],
    isa => 'ArrayRef[Web::Microformats2::Item]',
    default => sub { [] },
    lazy => 1,
    handles => {
        all_top_level_items => 'elements',
        add_top_level_item => 'push',
        count_top_level_items => 'count',
        has_top_level_items => 'count',
    },
);

has 'items' => (
    is => 'ro',
    traits => ['Array'],
    isa => 'ArrayRef[Web::Microformats2::Item]',
    default => sub { [] },
    lazy => 1,
    handles => {
        add_item => 'push',
        all_items => 'elements',
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

sub as_json {
    my $self = shift;

    my $data_for_json = {
        rels => $self->rels,
        'rel-urls' => $self->rel_urls,
        items => $self->top_level_items,
    };

    return JSON->new->convert_blessed->pretty->encode( $data_for_json );
}

sub from_json {
    my $class = shift;

    my ( $json ) = @_;

    my $data_ref = decode_json ($json);

    my @items;
    for my $deflated_item ( @{ $data_ref->{items} } ) {
        push @items, $class->_inflate_item( $deflated_item );
    }

    return $class->new(
        items => \@items,
    );
}

sub _inflate_item {
    my $class = shift;

    my ( $deflated_item ) = @_;

    foreach ( @{ $deflated_item->{type} } ) {
        s/^h-//;
    }

    my $item = $class->new(
        types => $deflated_item->{type},
    );

    if ( defined $deflated_item->{value} ) {
        $item->value( $deflated_item->{value} );
    }

    for my $deflated_child ( @{ $deflated_item->{children} } ) {
        $item->add_child ( $class->_inflate_item( $deflated_child ) );
    }

    for my $property ( keys %{ $deflated_item->{properties} } ) {
        my $properties_ref = $deflated_item->{properties}->{$property};
        for my $property_value ( @{ $properties_ref } ) {
            if ( ref( $property_value ) ) {
                $property_value = $class->_inflate_item( $property_value );
            }
            $item->add_property( $property, $property_value );
        }
    }

    return $item;
}

sub get_first {
    my $self = shift;

    my ( $type ) = @_;

    for my $item ( $self->all_items ) {
        return $item if $item->has_type( $type );
    }

    return;
}

1;
