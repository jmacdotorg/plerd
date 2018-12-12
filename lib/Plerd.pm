package Plerd;

our $VERSION = '1.72';

use Moose;
use MooseX::Types::URI qw(Uri);
use Template;
use Path::Class::Dir;
use File::Path;
use DateTime;
use DateTime::Format::W3CDTF;
use URI;
use File::Find;
use File::Copy;
use Carp;
use Try::Tiny;

use Plerd::Post;
use Plerd::WebmentionQueue;

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

has 'asset_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'publication_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'database_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'base_uri' => (
    is => 'ro',
    required => 1,
    isa => Uri,
    coerce => 1,
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

has 'twitter_id' => (
    is => 'ro',
    isa => 'Maybe[Str]',
    default => undef,
);

has 'facebook_id' => (
    is => 'ro',
    isa => 'Maybe[Str]',
    default => undef,
);

has 'image' => (
    is => 'ro',
    isa => Uri,
    coerce => 1,
);

has 'image_alt' => (
    is => 'ro',
    isa => 'Maybe[Str]',
    default => undef,
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

has 'asset_directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'template_directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'database_directory' => (
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

has 'index_of_post_with_url' => (
    is => 'ro',
    isa  => 'HashRef',
    lazy_build => 1,
    clearer => 'clear_post_url_index_hash',
);

has 'webmention_queue' => (
    is => 'ro',
    isa => 'Plerd::WebmentionQueue',
    lazy_build => 1,
);

sub BUILD {
    my $self = shift;

    unless ( $self->path ) {
        for my $subdir_type ( qw( source template publication database asset ) ) {
            try {
                my $method = "${subdir_type}_directory";
                my $dir = $self->$method;
            }
            catch {
                die "Can't create a new Plerd object, due to insufficient "
                    . "configuration: $_";
            };
        }
    }

    return $self;
}

sub publish_all {
    my $self = shift;

    for my $post ( @{ $self->posts } ) {
        $post->publish;
    }

    if (-d $self->asset_directory) {
        $self->publish_assets;
    }

    $self->publish_archive_page;

    $self->publish_recent_page;
    $self->publish_rss;
    $self->publish_jsonfeed;

    $self->clear_recent_posts;
    $self->clear_posts;
    $self->clear_post_index_hash;
    $self->clear_post_url_index_hash;
}

sub publish_assets {
    my $self = shift;

    find(sub { $self->_publish_asset($File::Find::name) if -f }, $self->asset_directory);
}

sub publish_recent_page {
    my $self = shift;

    $self->template->process(
        $self->post_template_file->open('<:encoding(utf8)'),
        {
            plerd => $self,
            posts => $self->recent_posts,
            title => $self->title,
        },
        $self->recent_file->open('>:encoding(utf8)'),
    ) || $self->_throw_template_exception( $self->post_template_file );

    my $index_file =
        Path::Class::File->new( $self->publication_directory, 'index.html' );
    symlink $self->recent_file, $index_file;
}

sub publish_rss {
    my $self = shift;

    $self->_publish_feed( 'rss' );
}

sub publish_jsonfeed {
    my $self = shift;

    $self->_publish_feed( 'jsonfeed' );
}

sub post_with_url {
    my $self = shift;
    my ( $url ) = @_;

    my $index = $self->index_of_post_with_url->{ $url };
    if ( defined $index ) {
        return $self->posts->[ $self->index_of_post_with_url->{ $url } ];
    }
    else {
        return;
    }
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
        $self->$template_file_method->open('<:encoding(utf8)'),
        {
            plerd => $self,
            posts => $self->recent_posts,
            timestamp => $timestamp,
        },
        $self->$file_method->open('>:encoding(utf8)'),
    ) || $self->_throw_template_exception( $self->$template_file_method );
}

sub _publish_asset {
    my $self = shift;

    my ($asset) = @_;

    my $pub_dir = Path::Class::File->new(
        $self->publication_directory
    );

    my $asset_dir = Path::Class::File->new($self->asset_directory);

    my $new_asset = Path::Class::File->new(
        $self->publication_directory,
        substr $asset, length $asset_dir
    );


    # Create directories if they dont exist
    my @new_asset_split = grep { $_ ne '' } (split "/", substr $new_asset, length $pub_dir);
    pop @new_asset_split;
    if (@new_asset_split > 0) {
        my $missing_directory = Path::Class::File->new($self->publication_directory, join "/", @new_asset_split);
        File::Path::make_path($missing_directory);
    }

    copy($asset, $new_asset);
}

sub publish_archive_page {
    my $self = shift;

    my $posts_ref = $self->posts;

    $self->template->process(
        $self->archive_template_file->open('<:encoding(utf8)'),
        {
            plerd => $self,
            posts => $posts_ref,
        },
        $self->archive_file->open('>:encoding(utf8)'),
    ) || $self->_throw_template_exception( $self->archive_template_file );

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
        die "Can't build $subdir_name directory! Neither a '$path_method' nor "
            . "a 'path' attribute is defined.\n";
    }
}

sub _build_source_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'source_path', 'source' );
}

sub _build_database_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'database_path', 'db' );
}

sub _build_publication_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'publication_path', 'docroot' );
}

sub _build_template_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'template_path', 'templates' );
}

sub _build_asset_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'asset_path', 'assets' );
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
            },
        },
        ENCODING => 'utf8',
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
                sort { $a->basename cmp $b->basename }
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

sub _build_index_of_post_with_url {
    my $self = shift;

    my %index_of_post;

    my $current_index = 0;

    for my $post ( @{ $self->posts } ) {
        $index_of_post{ $post->uri } = $current_index++;
    }

    return \%index_of_post;
}

sub _build_webmention_queue {
    my $self = shift;

    return Plerd::WebmentionQueue->new( plerd => $self );
}

sub _throw_template_exception {
    my $self = shift;
    my ( $template_file ) = @_;

    my $error = $self->template->error;

    die "Publication interrupted due to an error encountered while processing "
        . "template file $template_file: $error\n";
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

The remainder of this document describes method calls and other
information specific to the Plerd object class. (If you are using Plerd
to run a blog, you don't necessarily have to know any of this!)

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

And, optional keys:

=over

=item *

facebook_id

=item *

image

=item *

image_alt

=item *

twitter_id

=item *

recent_posts_maxsize I<Default value: 10>

=back

=back

=head1 OBJECT ATTRIBUTES

=head2 Read-only attributes, set during construction

=over

=item base_uri

L<URI> object representing the base URI for this blog, which the system will prepend
to any absolute links it builds.

=item facebook_id

(Optional) This blog's Facebook app ID.

=item image

(Optional) L<URI> object representing this blog's default image, for use in
social media metadata and such.

=item image_alt

(Optional) A text description of this blog's default image, for use in
social media metadata and such.

=item path

The path to a filesystem directory within which Plerd will look for
"source", "docroot", "templates", and "db" directories as needed, using those names exactly.

B<Caution:> If this is not defined I<and> any one of the previous three attributes
is also undefined, then Plerd will die if you try to publish the blog.

=item publication_path

The path to the filesystem directory containing this blog's output directory.

=item source_path

The path to the filesystem directory containing this blog's source directory.

=item template_path

The path to the filesystem directory containing this blog's templates directory.

=item database_path

The path to the filesystem directory containing this blog's database directory.

=item title

String representing this blog's title.

=item twitter_id

(Optional) This Twitter username associated with this blog. Does not include
the leading '@' character.

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

=item database_directory

A L<Path::Class::Dir> object representation of the directory that holds
the blogs's private, not-necessarily-human-readable data files.

=back

=head1 OBJECT METHODS

=over

=item publish_all

Publishes every Markdown file in the blog's source directory.
Also recreates the recent, archive, and syndication files.

=item post_with_url( $absolute_url )

Returns the Plerd::Post object that has the given absolute URL. Returns undef
if there is no such post.

=back

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
