use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use URI;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok( 'Plerd' );

# Prepare by making a fresh source directory, based on the source_model directory
# (and throw out said source dir if it's already there from e.g. a botched test)
my $source_dir = Path::Class::Dir->new( "$FindBin::Bin/source" );
$source_dir->rmtree;
$source_dir->mkpath;

my $now = DateTime->now( time_zone => 'local' );
my $ymd = $now->ymd;

my $model_dir = Path::Class::Dir->new( "$FindBin::Bin/source_model" );
foreach ( Path::Class::Dir->new( "$FindBin::Bin/source_model" )->children ) {
    my $filename = $_->basename;
    $filename =~ s/TODAY/$ymd/;
    my $destination = Path::Class::File->new( $source_dir, $filename );
    $_->copy_to( $destination );
}

# And then clean out the docroot.
my $docroot_dir = Path::Class::Dir->new( "$FindBin::Bin/docroot" );
$docroot_dir->rmtree;
$docroot_dir->mkpath;

# Now try to make a Plerd object, and send it through its paces.
my $plerd = Plerd->new(
    path         => $FindBin::Bin,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
);

eval { $plerd->publish_all; };
like ( $@, qr/not in W3C format/, 'Rejected source file with invalid timestamp.' );

unlink "$FindBin::Bin/source/bad-date.md";

eval { $plerd->publish_all; };
like ( $@, qr/post title/, 'Rejected title-free source file.' );

unlink "$FindBin::Bin/source/no-title.md";

$plerd->publish_all;

# The "+3" below accounts for the generated recent, archive, and RSS files.
my $expected_docroot_count = scalar( $source_dir->children( no_hidden => 1 ) ) + 3;
is( scalar( $docroot_dir->children ),
            $expected_docroot_count,
            "Correct number of files generated in docroot."
);

### Test formatting in titles and filenames
{
my $post = Path::Class::File->new( $docroot_dir, '1999-01-01-backdated.html' )->slurp;
like ( $post,
       qr{an <em>example</em> of a &#8220;backdated},
       'Post title is formatted.'
     );
}

### Test published-file naming
{
my $renamed_file =
    Path::Class::File->new( $docroot_dir, $ymd . '-a-good-source-file.html' );
my $not_renamed_file =
    Path::Class::File->new( $docroot_dir, '1999-01-01-backdated.html' );
is (-e $renamed_file, 1, 'Source file with dateless filename named as expected.' );
is (-e $not_renamed_file, 1, 'Source file with backdated filename named as expected.' );

my $renamed_file_with_funky_title =
    Path::Class::File->new(
        $docroot_dir,
        $ymd . '-apostrophes-and-html-shouldnt-turn-into-garbage.html',
    );
is (
    -e $renamed_file_with_funky_title,
    1,
    'Source file with formatted title received a nice clean published filename.'
);
}

### Make sure re-titling posts works as expected
{
my $source_file = Path::Class::File->new( $source_dir, 'good-source-file.md' );
my $text = $source_file->slurp;
$text =~ s/title: A good source file/title: A retitled source file/;
$source_file->spew( $text );

$plerd->publish_all;

my $welcome_file = Path::Class::File->new(
    $docroot_dir,
    $ymd . '-a-good-source-file.html',
);
my $unwelcome_file = Path::Class::File->new(
    $docroot_dir,
    $ymd . '-a-retitled-source-file.html',
);

is ( $docroot_dir->contains( $welcome_file ),
     1,
     'A file named after the old title is still there.',
);
isnt ( $docroot_dir->contains( $unwelcome_file ),
     1,
     'A file named after the new title is not there.',
);

$text =~ s/-a-good-source-file/-a-retitled-source-file/;
$source_file->spew( $text );

$plerd->publish_all;
is ( $docroot_dir->contains( $unwelcome_file ),
     1,
     'A file named after the new title is there now.',
);

### Test GUIDs

$plerd->publish_all;
like ( $source_file->slurp,
       qr/guid: /,
       'Source file contains a GUID, as expected.',
);

}

### Test using alternate config paths
{
my $alt_config_plerd = Plerd->new(
    source_path       => "$FindBin::Bin/source",
    publication_path  => "$FindBin::Bin/docroot",
    template_path     => "$FindBin::Bin/templates",
    title             => 'Test Blog',
    author_name       => 'Nobody',
    author_email      => 'nobody@example.com',
    base_uri          => URI->new ( 'http://blog.example.com/' ),
);

$docroot_dir->rmtree;
$docroot_dir->mkpath;

$alt_config_plerd->publish_all;
is( scalar( $docroot_dir->children ),
            $expected_docroot_count,
            "Correct number of files generated in docroot."
);


}
done_testing();
