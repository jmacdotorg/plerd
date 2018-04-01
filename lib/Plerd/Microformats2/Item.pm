package Plerd::Microformats2::Item;
use Moose;

has 'properties' => (
    is => 'ro',
    isa => 'HashRef',
    traits => ['Hash'],
    default => sub { {} },
    handles => {
        has_properties => 'count',
        has_property   => 'get',
    },
);

has 'children' => (
    is => 'ro',
    isa => 'ArrayRef[Plerd::Microformats2::Item]',
    default => sub { [] },
    traits => ['Array'],
    handles => {
        add_child => 'push',
    },
);

has 'types' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
);

has 'value' => (
    is => 'rw',
    isa => 'Maybe[Str]',
);

sub add_property {
    my $self = shift;

    my ( $key, $value ) = @_;

    $self->{properties}->{$key} ||= [];

    push @{ $self->{properties}->{$key} }, $value;
}

sub get_properties {
    my $self = shift;

    my ( $key ) = @_;

    return $self->{properties}->{$key} || [];
}

sub TO_JSON {
    my $self = shift;

    my $data = {
        properties => $self->properties,
        type => [ map { "h-$_" } @{ $self->types } ],
    };
    if ( defined $self->value ) {
        $data->{value} = $self->value;
    }
    if ( @{$self->children} ) {
        $data->{children} = $self->children;
    }
    return $data;
}

1;
