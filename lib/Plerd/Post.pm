package Plerd::Post;

use Moose;
use DateTime;
use DateTime::Format::W3CDTF;
use Text::Markdown qw( markdown );
use Text::SmartyPants;
use URI;

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
    is => 'ro',
    isa => 'Str',
    lazy_build => 1,
);

has 'uri' => (
    is => 'ro',
    isa => 'URI',
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
    $filename =~ s/\..*$/.html/;

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

sub _build_published_timestamp {
    my $self = shift;

    my $formatter = DateTime::Format::W3CDTF->new;
    my $timestamp = $formatter->format_datetime( $self->date );

    return $timestamp;
}

# This next internal method does a bunch of stuff.
# It's called via Moose-trigger when the object's source_file attribute is set.
# * Read and store the file's data (body) and metadata
# * Figure out the publication timestamp, based on possible (not guaranteed!)
#   presence of date in the filename AND/OR "time" metadata attribute
# * If the file lacks a timestamp attribute, rewrite the file so that it has one
# * If the file lacks a Plerd-style filename, rename it so that it has one
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
    $self->body( Text::SmartyPants::process( markdown( $body ) ) );

    close $fh;

    $self->title( $attributes{ title } );

    unless ( $attributes{ title } ) {
        die 'Error processing ' . $self->source_file . ': '
            . ' File content does not define a post title.'
        ;
    }

    # Note whether the filename asserts the post's publication date.
    my ( $filename_year, $filename_month, $filename_day ) =
        $self->source_file->basename =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/;

    # Set the post's date, using these rules:
    # * If the post has a time attribute in W3 format, use that
    # * Elsif the post's filename asserts a date, use midnight of that date,
    #   and also add a time attribute to the file.
    # * Else use right now, and also add a time attribute to the file.
    if ( $attributes{ time } ) {
        $self->date(
            $self->plerd->datetime_formatter->parse_datetime( $attributes{ time } )
        );
        $self->date->set_time_zone( 'local' );
        unless ( $self->date ) {
            die 'Error processing ' . $self->source_file . ': '
                . ' The "time" attribute is not in W3C format.'
            ;
        }
    }
    else {
        my $publication_dt;

        if ( $filename_year ) {
            # The post specifies its day in the filename, but we still don't have a
            # publication hour. So, just use midnight.
            $publication_dt = DateTime->new(
                year => $filename_year,
                month => $filename_month,
                day => $filename_day,
                time_zone => 'local',
            );
        }
        else {
            # The file doesn't name the time, *and* the file doesn't contain the date
            # in metadata (or else we wouldn't be here), so we'll just use right-now.
            $publication_dt = DateTime->now( time_zone => 'local' );
        }

        $self->date( $publication_dt );

        my $date_string =
            $self->plerd->datetime_formatter->format_datetime( $publication_dt );

        my $new_content = <<EOF;
title: $attributes{ title }
time: $date_string

$body
EOF
        $self->source_file->spew( $new_content );
    }

    # If the filename isn't Plerdish, rename the file.
    if ( not $filename_year ) {
        my ( $file_extension ) = $self->source_file =~ /\.(\w+)$/;
        my $new_filename = $self->title;
        $new_filename =~ s/\s+/-/g;
        $new_filename =~ s/--+/-/g;
        $new_filename =~ s/[^\w\-]+//g;
        $new_filename = lc $new_filename;
        $new_filename = $self->date->ymd( q{-} ) . q{-} . $new_filename;
        $new_filename .= ".$file_extension";
        my $new_location = Path::Class::File->new(
            $self->source_file->parent,
            $new_filename,
        );
        unless ( $self->source_file->move_to( $new_location ) ) {
            die "Failed to move " . $self->source_file . " to $new_filename.";
        }
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
