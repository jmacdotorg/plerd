package Plerd::Microformats2::Item;
use Moose;
use Carp;

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

has 'parent' => (
    is => 'ro',
    isa => 'Maybe[Plerd::Microformats2::Item]',
    weak_ref => 1,
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
    traits => ['Array'],
    handles => {
        find_type => 'first',
    },

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

sub get_property {
    my $self = shift;

    my $properties_ref = $self->get_properties( @_ );

    if ( @$properties_ref > 1 ) {
        carp "get_property called with multiple properties set\n";
    }

    return $properties_ref->[0];

}

sub has_type {
    my $self = shift;
    my ( $type ) = @_;

    $type =~ s/^h-//;

    return $self->find_type( sub { $_ eq $type } );
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
