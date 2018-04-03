package Plerd::Microformats2::Document;
use Moose;
use JSON;

has 'top_level_items' => (
    is => 'ro',
    traits => ['Array'],
    isa => 'ArrayRef[Plerd::Microformats2::Item]',
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
    isa => 'ArrayRef[Plerd::Microformats2::Item]',
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


sub get_first {
    my $self = shift;

    my ( $type ) = @_;

    for my $item ( $self->all_items ) {
        return $item if $item->has_type( $type );
    }

    return;
}

1;
