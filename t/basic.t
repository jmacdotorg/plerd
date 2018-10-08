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

# The "+4" below accounts for various non-post generated files.
my $expected_docroot_count = scalar( $source_dir->children( no_hidden => 1 ) ) + 4;
is( scalar( $docroot_dir->children ),
            $expected_docroot_count,
            "Correct number of files generated in docroot."
);

### Test reading time
{
my $post = $plerd->posts->[-1];
is ( $post->reading_time, 4, 'Reading time is as expected.' );
}

### Test formatting in titles and filenames
{
my $post = Path::Class::File->new( $docroot_dir, '1999-01-01-backdated.html' )->slurp;
like ( $post,
       qr{an <em>example</em> of a “backdated},
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

### Test miscellaneous-attribute pass-through
my $byline_post =
    Path::Class::File->new(
        $docroot_dir,
        '2000-01-01-this-post-has-extra-headers.html',
    );

like( $byline_post->slurp,
      qr/"byline">Sam Handwich/,
      'Miscellaneous header passed through to the template',
);

### Test newer / older post links
  # (Including robustness after new posts are added)
my $new_post =
    Path::Class::File->new(
        $source_dir,
        'another_post.md',
    );
$new_post->spew( "title:Blah\n\nWords, words, words." );
$expected_docroot_count++;
$plerd->publish_all;

my $first_post = $plerd->posts->[0];
my $second_post = $plerd->posts->[1];
my $third_post = $plerd->posts->[2];
my $last_post = $plerd->posts->[-1];
my $penultimate_post = $plerd->posts->[-2];
is( $first_post->newer_post, undef, 'First post has no newer post.' );
is( $first_post->older_post,
    $second_post,
    'First post has correct older post.'
);
is( $second_post->newer_post,
    $first_post,
    'Second post has correct newer post.'
);
is( $second_post->older_post,
    $third_post,
    'Second post has correct older post.'
);
is( $last_post->older_post,
    undef,
    'Last post has no older post.'
);
is( $last_post->newer_post,
    $penultimate_post,
    'Last post has correct newer post.'
);

}

### Test trailing no slash on base_uri
{
my $plerd = Plerd->new(
    path         => $FindBin::Bin,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://www.example.com/blog' ),
);

$plerd->publish_all;
like ( Path::Class::File->new( $docroot_dir, 'recent.html' )->slurp,
     qr{http://www.example.com/blog/1999-01-02-unicode.html},
     'Base URIs missing trailing slashes work',
);

}

### Test using alternate config paths
{
$docroot_dir->rmtree;
$docroot_dir->mkpath;

my $alt_config_plerd = Plerd->new(
    source_path       => "$FindBin::Bin/source",
    publication_path  => "$FindBin::Bin/docroot",
    template_path     => "$FindBin::Bin/templates",
    database_path     => "$FindBin::Bin/db",
    title             => 'Test Blog',
    author_name       => 'Nobody',
    author_email      => 'nobody@example.com',
    base_uri          => URI->new ( 'http://blog.example.com/' ),
);

$alt_config_plerd->publish_all;
is( scalar( $docroot_dir->children ),
            $expected_docroot_count,
            "Correct number of files generated in docroot."
);
}

### Test social-media metatags.
{
my $social_plerd = Plerd->new(
    path         => $FindBin::Bin,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
    image        => URI->new ( 'http://blog.example.com/logo.png' ),
    facebook_id  => 'This is a fake Facebook ID',
    twitter_id   => 'This is a fake Twitter ID',
);

$social_plerd->publish_all;

my $post = Path::Class::File->new( $docroot_dir, "$ymd-metatags.html" )->slurp;
my $image_post = Path::Class::File->new( $docroot_dir, "$ymd-metatags-with-image.html" )->slurp;
my $alt_image_post = Path::Class::File->new( $docroot_dir, "$ymd-metatags-with-image-and-alt.html" )->slurp;


like( $post,
    qr{name="twitter:image" content="http://blog.example.com/logo.png"},
    'Metatags: Default image',
);
like( $image_post,
    qr{name="twitter:image" content="http://blog.example.com/example.png"},
    'Metatags: Post image',
);
like( $alt_image_post,
    qr{name="twitter:image:alt" content="A lovely bunch of coconuts."},
    'Metatags: Post-specific alt-text',
);
like( $image_post,
    qr{name="twitter:image:alt" content=""},
    'Metatags: Empty default alt-text',
);

like( $post,
    qr{name="twitter:card" content="summary"},
    'Metatags: Default image is a thumbnail',
);
like( $image_post,
    qr{name="twitter:card" content="summary_large_image"},
    'Metatags: Post image is full-sized',
);

like( $post,
    qr{name="twitter:description" content="Fun with social metatags.},
    'Metatags: Defined description',
);

like ( $image_post,
    qr{name="twitter:description" content="This file sets up some attributes},
    'Metatags: Default description (with markup stripped)',
);

# Now add some alt text...
$social_plerd = Plerd->new(
    path         => $FindBin::Bin,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
    image        => URI->new ( 'http://blog.example.com/logo.png' ),
    facebook_id  => 'This is a fake Facebook ID',
    twitter_id   => 'This is a fake Twitter ID',
    image_alt    => 'Just a test image.',
);

$social_plerd->publish_all;
$post = Path::Class::File->new( $docroot_dir, "$ymd-metatags.html" )->slurp;
like( $post,
    qr{name="twitter:image:alt" content="Just a test image."},
    'Metatags: Defined default alt-text',
);

}

done_testing();
