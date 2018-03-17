package Plerd::Webmention;

use Moose;
use MooseX::ClassAttribute;
use MooseX::Types::URI qw(Uri);
use LWP;
use DateTime;

has 'source' => (
    isa => Uri,
    is => 'ro',
    required => 1,
    coerce => 1,
);

has 'target' => (
    isa => Uri,
    is => 'ro',
    required => 1,
    coerce => 1,
);

has 'is_verified' => (
    isa => 'Bool',
    is => 'ro',
    lazy_build => 1,
);

has 'time_verified' => (
    isa => 'DateTime',
    is => 'rw',
);

has 'time_received' => (
    isa => 'DateTime',
    is => 'ro',
    default => sub{ DateTime->now },
);

class_has 'ua' => (
    isa => 'LWP::UserAgent',
    is => 'ro',
    default => sub { LWP::UserAgent->new },
);

sub _build_is_verified {
    my $self = shift;

    return $self->verify;
}

sub verify {
    my $self = shift;

    my $response = $self->ua->get( $self->source );
    if ($response->content =~ $self->target ) {
        $self->time_verified( DateTime->now );
        return 1;
    }
    else {
        return 0;
    }
}

# Called by the JSON module during JSON encoding.
# Contrary to the (required) name, returns an unblessed reference, not JSON.
# See https://metacpan.org/pod/JSON#OBJECT-SERIALISATION
sub TO_JSON {
    my $self = shift;

    return {
        source => $self->source->as_string,
        target => $self->target->as_string,
        is_verified => $self->is_verified,
        time_received => $self->time_received->epoch,
        time_verified => $self->time_verified->epoch,
    };
}

# Class method to construct a Webmention object from an unblessed reference,
# as created from the TO_JSON method. All-caps-named for the sake of parity.
sub FROM_JSON {
    my $class = shift;
    my ( $data_ref ) = @_;

    foreach ( qw( time_received time_verified ) ) {
        $data_ref->{ $_ } = DateTime->from_epoch( epoch => $data_ref->{ $_ } );
    }

    return $class->new( $data_ref );
}

1;
