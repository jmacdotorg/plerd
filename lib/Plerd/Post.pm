package Plerd::Post;

use Moose;
use DateTime;
use Text::Markdown qw( markdown );
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

sub _process_source_file {
    my $self = shift;

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

    $self->title( $attributes{ title } );
    my ( $year, $month, $day ) =
        $self->source_file->basename =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/;

    unless ( $year ) {
        die 'Error processing ' . $self->source_file . ': '
            . ' Could not find a YYYY-MM-DD date in its filename.'
        ;
    }

    unless ( $attributes{ title } ) {
        die 'Error processing ' . $self->source_file . ': '
            . ' File content does not define a post title.'
        ;
    }


    $self->date( DateTime->new (
        year => $year,
        month => $month,
        day => $day,
        time_zone => 'GMT',
    ) );

    my $body;
    while ( <$fh> ) {
        $body .= $_;
    }
    $self->body( markdown( $body ) );
}

sub publish {
    my $self = shift;

    $self->plerd->template->process(
        $self->plerd->post_template_file->openr,
        {
            plerd => $self->plerd,
            posts => [ $self ],
        },
        $self->publication_file->openw,
    );
}


1;
