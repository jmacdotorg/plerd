package Web::Mention;

use Moose;
use MooseX::ClassAttribute;
use MooseX::Types::URI qw(Uri);
use LWP;
use DateTime;
use Try::Tiny;

use Web::Microformats2::Parser;
use Web::Mention::Author;

has 'source' => (
    isa => Uri,
    is => 'ro',
    required => 1,
    coerce => 1,
);

has 'source_html' => (
    isa => 'Maybe[Str]',
    is => 'rw',
);

has 'source_mf2_document' => (
    isa => 'Maybe[Web::Microformats2::Document]',
    is => 'rw',
    lazy_build => 1,
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

has 'author' => (
    isa => 'Maybe[Web::Mention::Author]',
    is => 'ro',
    lazy_build => 1,
);

has 'type' => (
    isa => 'Str',
    is => 'ro',
    lazy_build => 1,
);

has 'content' => (
    isa => 'Maybe[Str]',
    is => 'ro',
    lazy_build => 1,
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
        $self->source_html( $response->content );
        return 1;
    }
    else {
        return 0;
    }
}

sub _build_source_mf2_document {
    my $self = shift;

    return unless $self->is_verified;
    my $doc;
    try {
        my $parser = Web::Microformats2::Parser->new;
        $doc = $parser->parse( $self->source_html );
    }
    catch {
        die "Error parsing source HTML: $_";
    };
    return $doc;
}

sub _build_author {
    my $self = shift;

    return Web::Mention::Author->new_from_mf2_document(
        $self->source_mf2_document
    );
}

sub _build_type {
    my $self = shift;

    my $item = $self->source_mf2_document->get_first( 'h-entry' );
    return 'mention' unless $item;

    if ( $item->get_property( 'in-reply-to' ) ) {
        return 'reply';
    }
    elsif ( $item->get_property( 'like-of' ) ) {
        return 'like';
    }
    elsif ( $item->get_property( 'repost-of' )) {
        return 'repost';
    }
    else {
        return 'mention';
    }
}

sub _build_content {
    my $self = shift;
    # XXX This is inflexible and not on-spec

    my $item = $self->source_mf2_document->get_first( 'h-entry' );
    if ( $item->get_property( 'content' ) ) {
        return $item->get_property( 'content' )->{value};
    }
    else {
        return;
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
        type => $self->type,
        mf2_document_json =>
            $self->source_mf2_document
            ? $self->source_mf2_document->as_json
            : undef,
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

    my $webmention = $class->new( $data_ref );

    if ( my $mf2_json = $data_ref->{ mf2_document_json } ) {
        my $doc = Web::Microformats2::Document->from_json( $mf2_json );
        $webmention->source_mf2_document( $doc );
    }

    return $webmention;
}

1;
