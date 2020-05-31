package Plerd::WebmentionQueue;

use Moose;
use Path::Class::Dir;
use Data::GUID;
use Web::Mention;
use Scalar::Util qw(blessed);
use JSON;
use Try::Tiny;
use Carp qw(croak);

use Readonly;
Readonly my $DEFAULT_DIR_NAME => 'webmention_inbox';

has 'plerd' => (
    is       => 'ro',
    required => 1,
    isa      => 'Plerd',
    weak_ref => 1,
);

has 'directory' => (
    is         => 'ro',
    isa        => 'Path::Class::Dir',
    lazy_build => 1,
);

sub process () {
    my $self = shift;

    my $return_value = 0;

    for my $wm ($self->all_webmentions) {
        my $post = $self->plerd->post_with_url($wm->target);
        if ($wm->is_verified) {
            $post->add_webmention($wm);
            $return_value = 1;
        } else {
            # It's possible that the post has this webmention from earlier,
            # and we've received an intentionally invalid update of it, due
            # to e.g. the source getting updated and removing a citation.
            # To cover that case, we ask the post to delete this mention.
            $post->delete_webmention($wm);
        }
    }

    $self->clear_webmentions;

    return $return_value;
}

sub add_webmention ( $ ) {    ## no critic
    my ($self, $wm) = @_;

    unless (blessed($wm) && $wm->isa("Web::Mention")) {
        croak "Not a Web::Mention object!";
    }

    my $json = JSON->new->utf8->convert_blessed->encode($wm);

    my $file = Path::Class::File->new($self->directory, Data::GUID->new,);

    $file->spew(
        iomode => '>:encoding(UTF-8)',
        $json
    );
}

sub all_webmentions () {
    my $self = shift;

    my @wms;
    for my $file ($self->directory->children(no_hidden => 1)) {
        try {
            push @wms, Web::Mention->FROM_JSON(decode_json($file->slurp(iomode => '<:encoding(UTF-8)')));
        }
        catch {
            die "Failed to deserialize the webmention at $file: $_\n";
        };
    }

    return @wms;
}

sub clear_webmentions () {
    my $self = shift;

    for my $file ($self->directory->children(no_hidden => 1)) {
        $file->remove;
    }

    return;
}

sub _build_directory {
    my $self = shift;

    my $dir = Path::Class::Dir->new($self->plerd->database_directory, $DEFAULT_DIR_NAME,);

    unless (-e $dir) {
        mkdir $dir;
    }

    return $dir;
}

1;

=head1 NAME

Plerd::WebmentionQueue

=head1 DESCRIPTION

This class provides some internal methods used by Plerd to manage its "inbox"
queue of received but unprocessed webmentions. It offers no public API.

=head1 SEE ALSO

L<Plerd>

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
