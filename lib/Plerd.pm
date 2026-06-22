package Plerd;

our $VERSION = '1.901_001';

use Moose;
use MooseX::Types::URI qw(Uri);
use Template;
use Path::Class::Dir;
use DateTime;
use DateTime::Format::W3CDTF;
use URI;
use Carp;
use Try::Tiny;
use JSON;
use Digest::MD5;
use File::Temp ();

use Plerd::Post;
use Plerd::Tag;

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

has 'database_path' => (
    is => 'ro',
    isa => 'Str',
);

has 'tags_publication_path' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has 'base_uri' => (
    is => 'ro',
    required => 1,
    isa => Uri,
    coerce => 1,
);

has 'tags_index_uri' => (
    is => 'ro',
    isa => Uri,
    lazy_build => 1,
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

has 'tags_publication_directory' => (
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

has 'tags_template_file' => (
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

has 'has_tags' => (
    is => 'ro',
    isa => 'Bool',
    lazy_build => 1,
);

has 'tags_map' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

has 'tag_case_conflicts' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

sub BUILD {
    my $self = shift;

    unless ( $self->path ) {
        for my $subdir_type ( qw( source template publication database ) ) {
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

    $self->publish_tag_indexes;
    $self->report_tag_case_conflicts;

    $self->publish_archive_page;

    $self->publish_recent_page;
    $self->publish_rss;
    $self->publish_jsonfeed;

    $self->_clear_caches;
}

# Republish just enough to reflect a change to a single source file.
sub publish_file {
    my $self = shift;
    my ( $source_file ) = @_;

    # We hash the file's metadata block (everything above the first blank
    # line) and compare it against the hash stored, by basename, in the
    # db/posts.json index. A missing or changed hash means the change may
    # affect the blog's sidebar, archive, and tag pages -- so we republish
    # everything. An unchanged hash means only the post's body changed.
    #
    # For a body-only edit we always republish the post's own page. We touch
    # the recent page and feeds only if this post is actually in the recent
    # set; an edit to an older, out-of-feed post leaves every other file
    # alone. Either way we consult the index for ordering and recency, so we
    # never re-render the whole blog to publish one post.
    my $basename     = $source_file->basename;
    my $index        = $self->_read_post_index;
    my $stored       = $index->{ $basename };
    my $current_hash = $self->_hash_of_metadata_block( $source_file );

    if ( !defined $stored || $stored->{ hash } ne $current_hash ) {
        $self->publish_all;

        # publish_all may have rewritten source files (adding time, guid,
        # etc.), so recompute the whole index from the files as they are now.
        $self->_write_post_index( $self->_post_index_from_source );
    }
    else {
        my $post = Plerd::Post->new(
            plerd       => $self,
            source_file => $source_file,
        );
        $post->publish;

        my %is_recent = map { $_ => 1 } $self->_recent_basenames( $index );
        if ( $is_recent{ $basename } ) {
            $self->publish_recent_page;
            $self->publish_rss;
            $self->publish_jsonfeed;
        }

        $self->_clear_caches;
    }
}

sub _clear_caches {
    my $self = shift;

    $self->clear_recent_posts;
    $self->clear_posts;
    $self->clear_post_index_hash;
    $self->clear_post_url_index_hash;

    $self->tags_map( {} );
    $self->tag_case_conflicts( {} );
}

# The JSON index of the blog's posts, keyed by source-file basename. Each
# value is a record: { hash => <metadata-block MD5>, time => <W3C date> }.
# The hash answers "did this post's metadata change?"; the time is all the
# meta-work (ordering, recency, neighbor-finding) needs, since everything else
# derives from publication date. Together they let an incremental publish
# reason about the whole blog without re-rendering a single other post.
sub _post_index_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->database_directory,
        'posts.json',
    );
}

sub _read_post_index {
    my $self = shift;

    my $file = $self->_post_index_file;
    return {} unless -e $file;

    return JSON->new->decode(
        scalar $file->slurp( iomode => '<:encoding(utf8)' )
    );
}

sub _write_post_index {
    my $self = shift;
    my ( $index ) = @_;

    $self->_post_index_file->spew(
        iomode => '>:encoding(utf8)',
        JSON->new->canonical->pretty->encode( $index ),
    );
}

# Build an index record (hash + time) for one source file by reading only its
# leading metadata block -- the lines above the first blank line -- so no
# Markdown is rendered. Read as raw bytes so the MD5 is stable and wide
# characters don't trip up Digest::MD5.
sub _index_record_for_file {
    my $self = shift;
    my ( $source_file ) = @_;

    my $fh = $source_file->open('<:raw');
    my $block = '';
    while ( my $line = <$fh> ) {
        last unless $line =~ /\S/;
        $block .= $line;
    }
    close $fh;

    my ( $time ) = $block =~ /^time\s*:\s*(.+?)\s*$/mi;

    return {
        hash => Digest::MD5::md5_hex( $block ),
        time => $time,
    };
}

# Just the metadata-block hash for a single file, for change detection.
sub _hash_of_metadata_block {
    my $self = shift;
    my ( $source_file ) = @_;

    return $self->_index_record_for_file( $source_file )->{ hash };
}

sub _post_index_from_source {
    my $self = shift;

    my %index;
    for my $file ( grep { /\.markdown$|\.md$/ }
                   $self->source_directory->children )
    {
        $index{ $file->basename } = $self->_index_record_for_file( $file );
    }

    return \%index;
}

# Source-file basenames ordered newest-first by publication date (ties broken
# by basename), derived from the post index. Undated records (which shouldn't
# occur after a full publish) sort to the very end.
sub _ordered_basenames {
    my $self = shift;
    my ( $index ) = @_;
    $index ||= $self->_read_post_index;

    my $formatter = $self->datetime_formatter;
    my $epoch_zero = DateTime->from_epoch( epoch => 0 );
    my %date_of;
    for my $basename ( keys %$index ) {
        my $time = $index->{ $basename }->{ time };
        my $dt = $time && eval { $formatter->parse_datetime( $time ) };
        $date_of{ $basename } = $dt || $epoch_zero;
    }

    return sort {
        ( $date_of{ $b } <=> $date_of{ $a } ) || ( $a cmp $b )
    } keys %$index;
}

# The basenames that currently make up the recent set (the front page + feeds).
sub _recent_basenames {
    my $self = shift;
    my ( $index ) = @_;

    my @ordered = $self->_ordered_basenames( $index );
    my $max = $self->recent_posts_maxsize;
    $max = @ordered if @ordered < $max;

    return @ordered[ 0 .. $max - 1 ];
}

# Given a post's basename, return the basename of its neighbor in publication
# order: $offset of -1 is the next-newer post, +1 the next-older. Returns undef
# at the ends (or if the post isn't in the index). Used so an incrementally
# published post page can resolve its prev/next links without building the
# whole blog.
sub neighbor_basename {
    my $self = shift;
    my ( $basename, $offset ) = @_;

    my @ordered = $self->_ordered_basenames;
    my %position = map { $ordered[$_] => $_ } 0 .. $#ordered;

    my $i = $position{ $basename };
    return unless defined $i;

    my $j = $i + $offset;
    return if $j < 0 || $j > $#ordered;

    return $ordered[ $j ];
}

# Create a page that lists all available tags with
# links to those pages that list the articles that
# have those tags
sub publish_tag_indexes {
    my $self = shift;

    # tags.tt is the one non-critical template: if it's missing, publish the
    # rest of the blog anyway rather than dying. Warn only if the blog actually
    # uses tags and therefore loses content by skipping their pages.
    unless ( -e $self->tags_template_file ) {
        if ( $self->has_tags ) {
            carp "This blog uses tags, but its template directory has no "
                 . "tags.tt file. Skipping publication of tag pages.\n";
        }
        return;
    }

    my $tag_map = $self->tags_map;

    # Commentary: Ideally we'd just pass a sorted array of tag objects
    # to the template. But alas said template was designed before tags were
    # objects, and I didn't want to make Plerd users have to go mess around
    # in their templates in between minor Plerd versions. And thus, we
    # pull out some tag data into a hash and pass that in, instead.

    # Create all the individual tag pages
    for my $tag (values %$tag_map) {

        $self->_publish_template_to_file(
            $self->tags_template_file,
            {
                self_uri => $tag->uri,
                is_tags_page => 1,
                tags => { $tag->name => $tag->posts },
                plerd => $self,
            },
            $self->tags_publication_file($tag->name),
        );
    }

    # Create the tag index
    my %simplified_tag_map;
    for my $tag (values %$tag_map) {
        $simplified_tag_map{ $tag->name } = $tag->posts;
    }
    $self->_publish_template_to_file(
        $self->tags_template_file,
        {
            self_uri => $self->tags_index_uri,
            is_tags_index_page => 1,
            is_tags_page => 1,
            tags => \%simplified_tag_map,
            plerd => $self,
        },
        $self->tags_publication_file,
    );

}

sub publish_recent_page {
    my $self = shift;

    $self->_publish_template_to_file(
        $self->post_template_file,
        {
            plerd => $self,
            posts => $self->recent_posts,
            title => $self->title,
        },
        $self->recent_file,
    );

    my $index_file =
        Path::Class::File->new( $self->publication_directory, 'index.html' );
    # Swap index.html into place atomically: build the symlink under a temp
    # name, then rename() it over any existing index.html. (symlink() silently
    # fails if its destination already exists, and removing index.html first
    # would briefly 404 it on republication.)
    my $temp_link = Path::Class::File->new(
        $self->publication_directory, "index.html.$$.tmp"
    );
    $temp_link->remove if -e $temp_link || -l $temp_link;
    if ( symlink $self->recent_file, $temp_link ) {
        rename "$temp_link", "$index_file"
            or warn "Couldn't move the index.html symlink into place: $!\n";
    }
    else {
        warn "Couldn't create the index.html symlink pointing at "
            . $self->recent_file . ": $!\n";
    }
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

    $self->_publish_template_to_file(
        $self->$template_file_method,
        {
            plerd => $self,
            posts => $self->recent_posts,
            timestamp => $timestamp,
        },
        $self->$file_method,
    );
}

sub publish_archive_page {
    my $self = shift;

    $self->_publish_template_to_file(
        $self->archive_template_file,
        {
            plerd => $self,
            posts => $self->posts,
        },
        $self->archive_file,
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

sub _build_template {
    my $self = shift;

    return Template->new( {
        INCLUDE_PATH => $self->template_directory,
        FILTERS => {
            json => sub {
                my $text = shift;
                # Encode as a JSON string, which correctly escapes
                # backslashes, quotes, newlines, tabs, and other control
                # characters. Then strip the enclosing quotes, since the
                # template supplies its own.
                my $encoded = JSON->new->allow_nonref->encode( $text );
                $encoded =~ s/^"//;
                $encoded =~ s/"$//;
                return $encoded;
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

    # Incremental path: when the full post list hasn't been built (a body-only
    # republish), construct only the recent posts named by the index, rather
    # than rendering the whole blog just to find the newest few.
    unless ( $self->has_posts ) {
        return [
            map {
                Plerd::Post->new(
                    plerd       => $self,
                    source_file => $self->source_directory->file( $_ ),
                )
            } $self->_recent_basenames
        ];
    }

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

# Publish atomically: render into a temp file in the target's own directory,
# then rename() it into place. A rename(2) on the same filesystem is atomic, so
# a web server reading the published file always sees either the complete old
# file or the complete new one -- never a truncated or zero-length one. A render
# that dies partway through leaves the existing published file untouched.
sub _atomically_write {
    my $self = shift;
    my ( $target_file, $writer ) = @_;

    my ( $fh, $temp_path ) = File::Temp::tempfile(
        'plerd-XXXXXX',
        DIR    => $target_file->parent->stringify,
        UNLINK => 0,
    );
    binmode $fh, ':encoding(utf8)';

    my $ok = eval { $writer->( $fh ); 1 };
    my $error = $@;
    close $fh;

    unless ( $ok ) {
        unlink $temp_path;
        die $error;
    }

    # File::Temp creates the file mode 0600; restore the perms a normally
    # created file would get, so the web server can read it.
    chmod 0666 & ~umask, $temp_path;

    unless ( rename $temp_path, $target_file->stringify ) {
        my $rename_error = $!;
        unlink $temp_path;
        die "Couldn't move $temp_path into place as $target_file: "
            . "$rename_error\n";
    }
}

# Render a Template Toolkit template to a file, atomically (see
# _atomically_write). Dies via _throw_template_exception on a processing error,
# leaving any existing published file intact.
sub _publish_template_to_file {
    my $self = shift;
    my ( $template_file, $vars, $target_file ) = @_;

    $self->_atomically_write( $target_file, sub {
        my $out_fh = shift;
        my $in_fh = $template_file->open('<:encoding(utf8)')
            or die "Can't open template file $template_file for reading: $!\n";
        $self->template->process( $in_fh, $vars, $out_fh )
            or $self->_throw_template_exception( $template_file );
    } );
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

# Returns the blog's base_uri, guaranteed to end with a slash, so that
# URI->new_abs() builds correct URLs even when base_uri points at a
# subdirectory (e.g. http://example.com/blog).
sub base_uri_with_slash {
    my $self = shift;

    my $base_uri = $self->base_uri->clone;
    my $path = $base_uri->path;
    unless ( $path =~ m{/$} ) {
        $base_uri->path( "$path/" );
    }
    return $base_uri;
}

# Tag-related builders & methods
sub _build_tags_index_uri {
    my $self = shift;
    return URI->new_abs(
        'tags/',
        $self->base_uri_with_slash,
    );
}

sub _build_tags_publication_path { 'tags' }

sub _build_tags_publication_directory {
    my $self = shift;

    return $self->_build_subdirectory( 'tags_publication_path', 'docroot' );
}

sub _build_tags_template_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->template_directory,
        'tags.tt',
    );
}

sub _build_has_tags {
    my $self = shift;

    my $tags_map = $self->tags_map;

    if (scalar keys %$tags_map) {
        return 1;
    }
    else {
        return 0;
    }

}

# Return either the tags/index.html file
# or a tags/TAGNAME.html file if given a tag
sub tags_publication_file {
    my ($self, $tag) = @_;
    $tag //= 'index';

    my $file = Path::Class::File->new($self->publication_directory,
                                      $self->tags_publication_directory,
                                      "$tag.html");

    my $dir = $file->parent->stringify;
    if ( !-d $dir) {
        mkdir $dir || die ("Cannot make directory: '$dir'. Create it manually, please.");
    }

    return $file;
}

sub tag_named {
    my ( $self, $tag_name ) = @_;

    my $key = lc $tag_name;

    my $tag = $self->tags_map->{ $key };

    if ( $tag ) {
        $tag->ponder_new_name( $tag_name );
    }
    else {
        $tag = Plerd::Tag->new(
            name => $tag_name,
            plerd => $self,
        );
        $self->tags_map->{ $key } = $tag;
    }

    return $tag;
}

sub publish {
    my $self = shift;

    return $self->publish_all;
}

sub tag_uri {
    my ( $self, $tag_name ) = @_;

    my $tag = $self->tag_named( $tag_name );

    if ( $tag ) {
        return $tag->uri;
    }
    else {
        return $self->tags_index_uri;
    }
}

sub add_tag_case_conflict {
    my ( $self, $conflicting_tag, $existing_tag ) = @_;

    return unless $conflicting_tag ne $existing_tag;

    $self->tag_case_conflicts->{lc $existing_tag}->{$conflicting_tag} = 1;
    $self->tag_case_conflicts->{lc $existing_tag}->{$existing_tag} = 1;
}

sub report_tag_case_conflicts {
    my $self = shift;

    unless ( keys %{$self->tag_case_conflicts} ) {
        return;
    }

    my $warning = "This blog's tags include the following case-conflicts:\n";

    foreach ( keys %{$self->tag_case_conflicts} ) {
        my $conflicts = join ', ', sort keys %{$self->tag_case_conflicts->{$_}};
        $warning .= "$conflicts\n";
    }

    $warning .= "This can lead to unexpected behavior, broken links, and other\n"
             . "sadnesses and regrets. Please normalize these tags!\n";

    warn $warning;
}

1;

=encoding utf8

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

=item tags_publication_path

The path to the filesystem directory containing this blog's out
directory for tag index files.

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

=item tags_publication_directory

A L<Path::Class::Dir> object representation of the directory within the docroot that holds
tag index HTML files.

=item tag_index_uri

This is a L<URI> object that points to the tag index.  It is
particularly helpful when creating navigation.

=back

=head1 OBJECT METHODS

=over

=item publish_all

Publishes every Markdown file in the blog's source directory.
Also recreates the recent, archive, and syndication files.

=item publish_file( $source_file )

Republishes the blog in response to a change to a single source file,
given as a L<Path::Class::File> object.

Plerd hashes the file's leading metadata block (everything above the
first blank line) and compares it against the hash stored, keyed by the
file's basename, in the C<db/posts.json> index. If the hash is missing or
has changed -- meaning the change might affect shared pages such as the
sidebar, archive, or tag indexes -- this calls L<"publish_all"> and
rebuilds the index. If the hash is unchanged -- meaning only the post's
body changed -- this republishes just that one post's page. It also
refreshes the recent-posts page and the syndication feeds, but only when
the edited post is currently in the recent set; a body edit to an older,
out-of-feed post rewrites that post's page and nothing else. Ordering,
recency, and prev/next neighbors are all read from the index, so a single
post is republished without re-rendering the rest of the blog.

=item post_with_url( $absolute_url )

Returns the Plerd::Post object that has the given absolute URL. Returns undef
if there is no such post.

=item tag_uri( $tag )

If $tag is defined, returns a L<URI> object with the address of the web
page for the given tag.

Otherwise, returns a L<URI> object referring to the tag index page.

=item has_tags

If the blog's posts declare any tags at all, then this returns true. Otherwise,
returns false.

=back

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>

=head1 CONTRIBUTORS

=over

=item *

Petter Hassberg

=item *

Joe Johnston

=item *

Christian Sánchez

=item *

David Turner

=item *

Rebecca Turner

=back
