package Plerd::Tag;

use Moose;
use URI;

has 'plerd' => (
    is => 'ro',
    required => 1,
    isa => 'Plerd',
    weak_ref => 1,
);

has 'posts' => (
    is => 'ro',
    isa => 'ArrayRef[Plerd::Post]',
    default => sub { [] },
);

has 'name' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'uri' => (
    is => 'ro',
    isa => 'URI',
    lazy_build => 1,
);

sub add_post {
    my ($self, $post) = @_;

    push ( @{$self->posts}, $post );
}

sub ponder_new_name {
    my ($self, $new_name) = @_;

    my $current_name = $self->name;

    if ( $current_name eq $new_name ) {
        return;
    }
    elsif ( not ($current_name =~ /[[:upper:]]/) ) {
        $self->name( $new_name );
    }
}

sub _build_uri {
    my $self = shift;

    my $base_uri = $self->plerd->base_uri;
    if ($base_uri =~ /[^\/]$/) {
        $base_uri .= '/';
    }
    return URI->new_abs(
        lc $self->name . '.html',
        $base_uri,
    );
}

1;
