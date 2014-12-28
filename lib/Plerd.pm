package Plerd;

use Moose;
use Template;
use Path::Class::Dir;
use DateTime;
use DateTime::Format::W3CDTF;
use URI;

use Plerd::Post;

use Readonly;
Readonly my $RECENT_POSTS_COUNT => 10;

has 'path' => (
    is => 'ro',
    required => 1,
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

has 'recent_post_files' => (
    is => 'ro',
    isa => 'ArrayRef[Path::Class::File]',
    lazy_build => 1,
);

has 'publication_directory' => (
    is => 'ro',
    isa => 'Path::Class::Dir',
    lazy_build => 1,
);

has 'files_to_publish' => (
    is => 'rw',
    isa => 'ArrayRef[Path::Class::File]',
    traits => ['Array'],
    handles => {
        number_of_files_to_publish => 'count',
        there_are_files_to_publish => 'count',
    },
    clearer => 'clear_files_to_publish',
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

has 'requires_recent_page_update' => (
    is => 'ro',
    isa => 'Bool',
    lazy_build => 1,
);

has 'recent_posts' => (
    is => 'ro',
    isa => 'ArrayRef[Plerd::Post]',
    lazy_build => 1,
);

sub publish {
    my $self = shift;

    return unless ( $self->there_are_files_to_publish );

    for my $file ( @{ $self->files_to_publish } ) {
        my $post = Plerd::Post->new(
            source_file => $file,
            plerd => $self,
        );

        $post->publish;
    }

    $self->publish_archive_page;

    if ( $self->requires_recent_page_update ) {
        $self->publish_recent_page;
        $self->publish_rss;
    }

    $self->clear_files_to_publish;

}

sub publish_all {
    my $self = shift;

    $self->files_to_publish(
        [ grep { /\.markdown$|\.md/ } $self->source_directory->children ]
    );

    $self->publish;
}

sub publish_recent_page {
    my $self = shift;

    $self->template->process(
        $self->post_template_file->openr,
        {
            plerd => $self,
            posts => $self->recent_posts,
        },
        $self->recent_file->openw,
    );
}

sub publish_rss {
    my $self = shift;

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp =
        $formatter->format_datetime( DateTime->now( time_zone => 'UTC' ) )
    ;

    $self->template->process(
        $self->rss_template_file->openr,
        {
            plerd => $self,
            posts => $self->recent_posts,
            timestamp => $timestamp,
        },
        $self->rss_file->openw,
    );


}

sub publish_archive_page {
    my $self = shift;

    my @posts = map { Plerd::Post->new( plerd => $self, source_file => $_ ) }
                grep { /\.markdown$|\.md/ }
                reverse sort
                $self->source_directory->children
    ;

    $self->template->process(
        $self->archive_template_file->openr,
        {
            plerd => $self,
            posts => \@posts,
        },
        $self->archive_file->openw,
    );

}


sub _build_directory {
    my $self = shift;

    return Path::Class::Dir->new( $self->path );
}

sub _build_source_directory {
    my $self = shift;

    return Path::Class::Dir->new(
        $self->directory,
        'source',
    );
}

sub _build_publication_directory {
    my $self = shift;

    return Path::Class::Dir->new(
        $self->directory,
        'docroot',
    );
}

sub _build_template_directory {
    my $self = shift;

    return Path::Class::Dir->new(
        $self->directory,
        'templates',
    );
}

sub _build_template {
    my $self = shift;

    return Template->new( {
        INCLUDE_PATH => $self->template_directory,
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


sub _build_requires_recent_page_update {
    my $self = shift;

    return 1;
}

sub _build_recent_posts {
    my $self = shift;

    return [
        map { Plerd::Post->new( plerd => $self, source_file => $_ ) }
        grep { /\.markdown$|\.md/ }
        ( reverse sort $self->source_directory->children )[0..$RECENT_POSTS_COUNT]
    ];
}

1;

