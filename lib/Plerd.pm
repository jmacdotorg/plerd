package Plerd;

our $VERSION = '1.42';

use Moose;
use Template;
use Path::Class::Dir;
use DateTime;
use DateTime::Format::W3CDTF;
use URI;
use Carp;

use Plerd::Post;

has 'path' => (
    is => 'ro',
    isa => 'Str',
);

has 'source_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'template_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'publication_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'base_uri' => (
    is => 'ro',
    required => 1,
    isa => 'URI',
);

has 'title' => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

has 'author_name' => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

has 'author_email' => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

has 'recent_posts_maxsize' => (
    is => 'ro',
    isa => 'Int',
    default => 10,
);

has 'directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'source_directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'template_directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'publication_directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'template' => (
    is => 'ro',
    isa => 'Template',
    lazy_build => 1,
);

has 'post_template_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'archive_template_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'rss_template_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'jsonfeed_template_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'recent_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'archive_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'rss_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'jsonfeed_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'recent_posts' => (
    is => 'ro',
    isa => 'ArrayRef[Plerd::Post]',
    lazy_build => 1,
    clearer => 'clear_recent_posts',
);

has 'datetime_formatter' => (
    is => 'ro',
    isa => 'DateTime::Format::W3CDTF',
    default => sub { DateTime::Format::W3CDTF->new },
);

has 'posts' => (
    is => 'ro',
    isa => 'ArrayRef[Plerd::Post]',
    lazy_build => 1,
    clearer => 'clear_posts',
);

has 'index_of_post_with_guid' => (
    is => 'ro',
    isa  => 'HashRef',
    lazy_build => 1,
    clearer => 'clear_post_index_hash',
);

sub publish_all {
    my $self = shift;

    for my $post ( @{ $self->posts } ) {
        $post->publish;
    }

    $self->publish_archive_page;

    $self->publish_recent_page;
    $self->publish_rss;
    $self->publish_jsonfeed;

    $self->clear_recent_posts;
    $self->clear_posts;
    $self->clear_post_index_hash;
}

sub publish_recent_page {
    my $self = shift;

    $self->template->process(
        $self->post_template_file->openr,
        {
            plerd => $self,
            posts => $self->recent_posts,
            title => $self->title,
        },
        $self->recent_file->openw,
    );
}

sub publish_rss {
    my $self = shift;

    $self->_publish_feed( 'rss' );
}

sub publish_jsonfeed {
    my $self = shift;

    $self->_publish_feed( 'jsonfeed' );
}

sub _publish_feed {
    my $self = shift;
    my ( $feed_type ) = @_;

    my $template_file_method = "${feed_type}_template_file";
    my $file_method          = "${feed_type}_file";

    return unless -e $self->$template_file_method;

    my $formatter = $self->datetime_formatter;
    my $timestamp =
        $formatter->format_datetime( DateTime->now( time_zone => 'local' ) )
    ;

    $self->template->process(
        $self->$template_file_method->openr,
        {
            plerd => $self,
            posts => $self->recent_posts,
            timestamp => $timestamp,
        },
        $self->$file_method->openw,
    );
}

sub publish_archive_page {
    my $self = shift;

    my $posts_ref = $self->posts;

    $self->template->process(
        $self->archive_template_file->openr,
        {
            plerd => $self,
            posts => $posts_ref,
        },
        $self->archive_file->openw,
    );

}


sub _build_directory {
    my $self = shift;

    if ( defined $self->path ) {
        return Path::Class::Dir->new( $self->path );
    }
    else {
        return undef;
    }
}

sub _build_subdirectory {
    my $self = shift;
    my ( $path_method, $subdir_name ) = @_;

    if ( defined $self->$path_method ) {
        return Path::Class::Dir->new( $self->$path_method );
    }
    elsif ( defined $self->path ) {
        return Path::Class::Dir->new(
            $self->directory,
            $subdir_name,
        );
    }
    else {
        die "Can't build source directory! Neither a '$path_method' nor"
            . "a 'path' attribute is defined.\n";
    }
}

sub _build_source_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'source_path', 'source' );
}

sub _build_publication_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'publication_path', 'docroot' );
}

sub _build_template_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'template_path', 'templates' );
}

sub _build_template {
    my $self = shift;

    return Template->new( {
        INCLUDE_PATH => $self->template_directory,
        FILTERS => {
            json => sub {
                my $text = shift;
                $text =~ s/"/\\"/g;
                $text =~ s/\n/\\n/g;
                return $text;
            }
        },

    } );
}

sub _build_post_template_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->template_directory,
        'post.tt',
    );
}

sub _build_rss_template_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->template_directory,
        'atom.tt',
    );
}

sub _build_jsonfeed_template_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->template_directory,
        'jsonfeed.tt',
    );
}

sub _build_archive_template_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->template_directory,
        'archive.tt',
    );
}

sub _build_recent_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->publication_directory,
        'recent.html',
    );
}

sub _build_archive_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->publication_directory,
        'archive.html',
    );
}

sub _build_rss_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->publication_directory,
        'atom.xml',
    );
}

sub _build_jsonfeed_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->publication_directory,
        'feed.json',
    );
}

sub _build_recent_posts {
    my $self = shift;

    my @recent_posts = ();

    for my $post ( @{ $self->posts } ) {

        my $did_update = 0;

        if ( @recent_posts < $self->recent_posts_maxsize ) {
            push @recent_posts, $post;
            $did_update = 1;
        }
        elsif ( $post->date > $recent_posts[ -1 ]->date ) {
            pop @recent_posts;
            push @recent_posts, $post;
            $did_update = 1;
        }

        if ( $did_update ) {
            @recent_posts = sort { $b->date <=> $a->date } @recent_posts;
        }
    }

    return \@recent_posts;
}

sub _build_posts {
    my $self = shift;

    my @posts = sort { $b->date <=> $a->date }
                map { Plerd::Post->new( plerd => $self, source_file => $_ ) }
                grep { /\.markdown$|\.md$/ }
                $self->source_directory->children
    ;

    return \@posts;
}

sub _build_index_of_post_with_guid {
    my $self = shift;

    my %index_of_post;

    my $current_index = 0;

    for my $post ( @{ $self->posts } ) {
        $index_of_post{ $post->guid } = $current_index++;
    }

    return \%index_of_post;
}

sub generates_post_guids {
    carp "generates_post_guids() is deprecated. (Also, it doesn't do anything "
         . "anyway.)";
}

sub publish {
    my $self = shift;

    return $self->publish_all;
}

1;

=head1 NAME

Plerd - Ultralight blogging with Markdown and Dropbox

=head1 DESCRIPTION

Plerd is a very lightweight system for writing and maintaining a blog based on
Markdown files stored in a Dropbox-synced directory.

For instructions on installing and using Plerd, please see the README file that
should have accompanied this distribution. It is also available online
at L<https://github.com/jmacdotorg/plerd#plerd>.

The remainder of this document describes method calls and other information
specific to the Plerd object class.

=head1 CLASS METHODS

=over

=item new( \%config )

Object constructor. The single config hashref I<must> include the following keys,
each of which maps to the object attribute of the same name
(see L<"OBJECT ATTRIBUTES">).

=over

=item *

path

=item *

title

=item *

base_uri

=item *

author_name

=item *

author_email

=back

And, optional keys, with defaults:

=over

=item *

recent_posts_maxsize I<Default value: 10>

=back

=back

=head1 OBJECT ATTRIBUTES

=head2 Read-only attributes, set during construction

=over

=item source_path

The path to the filesystem directory containing this blog's source directory.

=item template_path

The path to the filesystem directory containing this blog's templates directory.

=item publication_path

The path to the filesystem directory containing this blog's output directory.

=item path

The path to a filesystem directory within which Plerd will look for
"source", "docroot", and "templates" directories as needed, using those names exactly.

B<Caution:> If this is not defined I<and> any one of the previous three attributes
is also undefined, then Plerd will die if you try to publish the blog.

=item title

String representing this blog's title.

=item base_uri

L<URI> object representing the base URI for this blog, which the system will prepend
to any absolute links it builds.

=item recent_posts_maxsize

Integer representing the maximum size of the recent_posts array, which in turn
defines how many posts (at most) appear on the blog's front page and syndication
document.

=back

=head2 Read-only attributes

=over

=item posts

An arrayref of L<Plerd::Post> objects, representing all the blog's posts, in
newest-to-oldest order. (Recency is determined by the dates manually
set on the posts by the posts' author, not on their source files' modification
time or whatever.)

=item recent_posts

An arrayref of L<Plerd::Post> objects, representing the most recent posts made to
the blog, in newest-to-oldest order. (Recency is determined by the dates manually
set on the posts by the posts' author, not on their source files' modification
time or whatever.)

The size of the array is no larger than the current value of the Plerd
object's C<recent_posts_maxsize> attribute (and thus will be equal to that number
for any blog whose total number of posts is greater than that number).

=item directory

A L<Path::Class::Dir> object representation of the path provided via this object's
C<path> attribute. If said attribute is undefined, then this will return undef.

=item source_directory

A L<Path::Class::Dir> object representation of the Dropbox-synced directory that holds
the blog's Markdown-based source files.

=item template_directory

A L<Path::Class::Dir> object representation of the Dropbox-synced directory that holds
the blog's Template Toolkit-based template files. (See also L<Template>.)

=item publication_directory

A L<Path::Class::Dir> object representation of the Dropbox-synced directory that holds
the blog's docroot -- in other words, the place Plerd will write HTML and XML files to.

=back

=head1 OBJECT METHODS

=over

=item publish_all

Publishes every Markdown file in the blog's source directory.
Also recreates the recent, archive, and syndication files.

=back

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
