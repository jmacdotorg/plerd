package Plerd::Post;

use Moose;
use DateTime;
use DateTime::Format::W3CDTF;
use Text::Markdown qw( markdown );
use Text::SmartyPants;
use URI;
use HTML::Strip;
use Data::GUID;

has 'plerd' => (
    is => 'ro',
    required => 1,
    isa => 'Plerd',
    weak_ref => 1,
);

has 'source_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    required => 1,
    trigger => \&_process_source_file,
);

has 'publication_file' => (
    is => 'ro',
    isa => 'Path::Class::File',
    lazy_build => 1,
);

has 'title' => (
    is => 'rw',
    isa => 'Str',
);

has 'body' => (
    is => 'rw',
    isa => 'Str',
);

has 'date' => (
    is => 'rw',
    isa => 'DateTime',
    handles => [ qw(
        month
        month_name
        day
        year
        ymd
    ) ],
);

has 'published_filename' => (
    is => 'rw',
    isa => 'Str',
    lazy_build => 1,
);

has 'uri' => (
    is => 'ro',
    isa => 'URI',
    lazy_build => 1,
);

has 'guid' => (
    is => 'rw',
    isa => 'Maybe[Data::GUID]',
    lazy_build => 1,
);

has 'updated_timestamp' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has 'published_timestamp' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has 'newer_post' => (
    is => 'ro',
    isa => 'Maybe[Plerd::Post]',
    lazy_build => 1,
);

has 'older_post' => (
    is => 'ro',
    isa => 'Maybe[Plerd::Post]',
    lazy_build => 1,
);

sub _build_publication_file {
    my $self = shift;

    return Path::Class::File->new(
        $self->plerd->publication_directory,
        $self->published_filename,
    );
}

sub _build_published_filename {
    my $self = shift;

    my $filename = $self->source_file->basename;

    # If the source filename already seems Plerdish, just replace its extension.
    # Else, generate a Plerdish filename based on the post's date and title.
    if ( $filename =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/ ) {
        $filename =~ s/\..*$/.html/;
    }
    else {
        $filename = $self->title;
        my $stripper = HTML::Strip->new( emit_spaces => 0 );
        $filename = $stripper->parse( $filename );
        $filename =~ s/\s+/-/g;
        $filename =~ s/--+/-/g;
        $filename =~ s/[^\w\-]+//g;
        $filename = lc $filename;
        $filename = $self->date->ymd( q{-} ) . q{-} . $filename;
        $filename .= '.html';
    }

    return $filename;
}

sub _build_uri {
    my $self = shift;

    return URI->new_abs(
        $self->published_filename,
        $self->plerd->base_uri,
    );
}

sub _build_updated_timestamp {
    my $self = shift;

    my $mtime = $self->source_file->stat->mtime;

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp = $formatter->format_datetime(
        DateTime->from_epoch(
            epoch     => $mtime,
            time_zone => 'local',
        ),
    );

    return $timestamp;
}

sub _build_newer_post {
    my $self = shift;

    my $index = $self->plerd->index_of_post_with_guid->{ $self->guid };

    my $newer_post;
    if ( $index - 1 >= 0 ) {
        $newer_post = $self->plerd->posts->[ $index - 1 ];
    }

    return $newer_post;
}

sub _build_older_post {
    my $self = shift;

    my $index = $self->plerd->index_of_post_with_guid->{ $self->guid };

    my $older_post = $self->plerd->posts->[ $index + 1 ];

    return $older_post;
}

sub _build_published_timestamp {
    my $self = shift;

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp = $formatter->format_datetime( $self->date );

    return $timestamp;
}

sub _build_guid {
    my $self = shift;

    return Data::GUID->new;
}

# This next internal method does a bunch of stuff.
# It's called via Moose-trigger when the object's source_file attribute is set.
# * Read and store the file's data (body) and metadata
# * Figure out the publication timestamp, based on possible (not guaranteed!)
#   presence of date in the filename AND/OR "time" metadata attribute
# * If the file lacks a timestamp attribute, rewrite the file so that it has one
# * If the file lacks a filename attribute, rewrite the file so that it has one
sub _process_source_file {
    my $self = shift;

    # Slurp the file, storing the title and time metadata, and the body.
    my $fh = $self->source_file->openr;
    my %attributes;
    while ( my $line = <$fh> ) {
        chomp $line;
        last unless $line =~ /\S/;
        my ($key, $value) = $line =~ /^\s*(\w+?)\s*:\s*(.*)$/;
        if ( $key ) {
            $attributes{ lc $key } = $value;
        }

    }

    my $body;
    while ( <$fh> ) {
        $body .= $_;
    }

    close $fh;

    if ( $attributes{ title } ) {
        $self->title( $attributes{ title } );
    }
    else {
        die 'Error processing ' . $self->source_file . ': '
            . 'File content does not define a post title.'
        ;
    }
    $self->body( $body );

    foreach ( qw( title body ) ) {
        $self->$_( Text::SmartyPants::process( markdown( $self->$_ ) ) );
    }

    # Strip unnecessary <p> tags that the markdown processor just added to the title.
    my $stripped_title = $self->title;
    $stripped_title =~ s{</?p>\s*}{}g;
    $self->title( $stripped_title );

    # Note whether the filename asserts the post's publication date.
    my ( $filename_year, $filename_month, $filename_day ) =
        $self->source_file->basename =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/;

    # Set the post's date, using these rules:
    # * If the post has a time attribute in W3 format, use that
    # * Elsif the post's filename asserts a date, use midnight of that date,
    #   and also add a time attribute to the file.
    # * Else use right now, and also add a time attribute to the file.
    my $attributes_need_to_be_written_out = 0;
    if ( $attributes{ time } ) {
        eval {
            $self->date(
                $self->plerd->datetime_formatter->parse_datetime( $attributes{ time } )
            );
            $self->date->set_time_zone( 'local' );
        };
        unless ( $self->date ) {
            die 'Error processing ' . $self->source_file . ': '
                . 'The "time" attribute is not in W3C format.'
            ;
        }
    }
    else {
        my $publication_dt;

        if ( $filename_year ) {
            # The post specifies its day in the filename, but we still don't have a
            # publication hour.
            # If the filename's date is today (locally), use the current time.
            # Otherwise, use midnight of the provided date.
            my $now = DateTime->now( time_zone => 'local' );
            my $ymd = $now->ymd( q{-} );
            if ( $self->source_file->basename =~ /^$ymd/ ) {
                $publication_dt = $now;
            }
            else {
                $publication_dt = DateTime->new(
                    year => $filename_year,
                    month => $filename_month,
                    day => $filename_day,
                    time_zone => 'local',
                );
            }
        }
        else {
            # The file doesn't name the time, *and* the file doesn't contain the date
            # in metadata (or else we wouldn't be here), so we'll just use right-now.
            $publication_dt = DateTime->now( time_zone => 'local' );
        }

        $self->date( $publication_dt );

        my $date_string =
            $self->plerd->datetime_formatter->format_datetime( $publication_dt );

        $attributes{ time } = $date_string;
        $attributes_need_to_be_written_out = 1;
    }

    if ( $attributes{ published_filename } ) {
        $self->published_filename( $attributes{ published_filename } );
    }
    else {
        $attributes{ published_filename } = $self->published_filename;
        $attributes_need_to_be_written_out = 1;
    }

    if ( $attributes{ guid } ) {
        $self->guid( Data::GUID->from_string( $attributes{ guid } ) );
    }
    else {
        $attributes{ guid } = $self->guid;
        $attributes_need_to_be_written_out = 1;
    }

    if ( $attributes_need_to_be_written_out ) {
        my $new_content = <<EOF;
title: $attributes{ title }
time: $attributes{ time }
published_filename: $attributes{ published_filename }
guid: $attributes{ guid }

$body
EOF
        $self->source_file->spew( $new_content );
    }
}

sub publish {
    my $self = shift;

    $self->plerd->template->process(
        $self->plerd->post_template_file->openr,
        {
            plerd => $self->plerd,
            posts => [ $self ],
            title => $self->title,
        },
        $self->publication_file->openw,
    );
}


1;

=head1 NAME

Plerd::Post - A Plerd blog post

=head1 DESCRIPTION

An object of the class Plerd::Post represents a single post to a
Plerd-based blog, with Markdown source and HTML output.

=head1 CLASS METHODS

=over

=item new( \%config )

Object constructor. The single config hashref I<must> include the following keys:

=over

=item plerd

The parent Plerd object.

=item source_file

A Path::Class::File object representing this post's Markdown source file.

=back

=back

=head1 OBJECT ATTRIBUTES

=head2 Read-only attributes

=over

=item published_filename

The local filename (without parent directory path) of the HTML file that this post
will generate upon publication.

=item uri

The L<URI> of the of the HTML file that this post will generate upon publication.

=item published_timestamp

This post's date, in W3C format, set to midnight in the local timezone.

=item updated_timestamp

The modification time of this this post's source file, in W3C format, set to
the local timezone.

=item older_post

A Plerd::Post object representing the next-older post to the blog.

Is the current object represents the oldest post in the blog, then this method
returns undef.

=item newer_post

A Plerd::Post object representing the next-newer post to the blog.

Is the current object represents the newest post in the blog, then this method
returns undef.

=back

=head2 Read-write attributes

=over

=item title

String representing this post's title.

=item date

L<DateTime> object representing this post's presented publication date.

=item body

String representing the post's body text.

=back

=head1 OBJECT METHODS

=over

=item publish

Publishes the post.

=back

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
