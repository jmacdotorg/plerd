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

use Plerd::Init;

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/testblog" );
$blog_dir->rmtree;

my $init_messages_ref = Plerd::Init::initialize( $blog_dir->stringify, 0 );
unless (-e $blog_dir) {
    die "Failed to create $blog_dir: @$init_messages_ref\n";
}

my $now = DateTime->now( time_zone => 'local' );
my $ymd = $now->ymd;

my $source_dir = Path::Class::Dir->new( $blog_dir, 'source' );
my $docroot_dir = Path::Class::Dir->new( $blog_dir, 'docroot' );
my $model_dir = Path::Class::Dir->new( "$FindBin::Bin/source_model" );
foreach ( Path::Class::Dir->new( "$FindBin::Bin/source_model" )->children ) {
    my $filename = $_->basename;
    $filename =~ s/TODAY/$ymd/;
    my $destination = Path::Class::File->new( $source_dir, $filename );
    $_->copy_to( $destination );
}

# Now try to make a Plerd object, and send it through its paces.
my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
);

eval { $plerd->publish_all; };
like ( $@, qr/not in W3C format/, 'Rejected source file with invalid timestamp.' );

unlink "$blog_dir/source/bad-date.md";

eval { $plerd->publish_all; };
like ( $@, qr/post title/, 'Rejected title-free source file.' );

unlink "$blog_dir/source/no-title.md";

$plerd->publish_all;

# The "+6" below accounts for the generated recent, archive, and RSS files,
# a index.html symlink, a JSON feed file, and a tags directory.
my $expected_docroot_count = scalar( $source_dir->children( no_hidden => 1 ) ) + 6;
is( scalar( $docroot_dir->children ),
            $expected_docroot_count,
            "Correct number of files generated in docroot."
);

### Test reading time
{
my $post = $plerd->posts->[-1];
is ( $post->reading_time, 4, 'Reading time is as expected.' );
}

### Test dates and time zones
{
my $post = $plerd->posts->[-1];
is ( $post->utc_date->offset, 0, 'Output of utc_date looks correct.' );
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

### Make sure tag pages look as expected
{
my $tag_index_file =
    Path::Class::File->new( $docroot_dir, 'tags', 'index.html' );
my $tag_detail_file =
    Path::Class::File->new( $docroot_dir, 'tags', 'bar with spaces.html' );

is (-e $tag_index_file, 1, 'Tag index file created.');
is (-e $tag_detail_file, 1, 'Tag detail file created.');

is ($plerd->has_tags, 1, 'The blog knows that it has tags.');

my $foo_tag_file =
    Path::Class::File->new( $docroot_dir, 'tags', 'foo.html' );
my $tag_detail_content = $foo_tag_file->slurp;
like(
    $tag_detail_content,
    qr{<h1>Tag: foo.*<li>.*<li>.*</ul>.*sidebar"}s,
    "The 'foo' tag page links to two posts, even though they capitalized "
    . "it differently.",
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

### Make sure descriptions work in different cases.
is ( $plerd->post_with_url( "http://blog.example.com/$ymd-metatags.html" )->description,
     'Fun with social metatags.',
     'Manually-set post description works.',
);
like ( $plerd->post_with_url( "http://blog.example.com/$ymd-metatags-with-image.html" )->description,
    qr/This file sets up some attributes/,
    'Automatically derived description works.',
);
like ( $plerd->post_with_url( "http://blog.example.com/$ymd-metatags-with-image-and-alt.html" )->description,
    qr/This file, which is awesome, sets up some attributes/,
    'Automatically derived description works, with leading image tag present.',
);

# make sure that multimarkdown tables work
like ( $plerd->post_with_url( "http://blog.example.com/$ymd-markdown-table.html")->body,
    qr{<td>Pizza</td>},
    'Markdown tables are rendered.',
);

### Test miscellaneous-attribute pass-through
# We need to edit the post template so it'll do something with a received
# pass-through attribute.
my $post_template =
    Path::Class::File->new(
        $blog_dir,
        'templates',
        'post.tt',
    );
my $post_template_content = $post_template->slurp;
$post_template_content =~
    s{<div class="body e-content">}
    {<div class="byline">[% post.attributes.byline %]</div><div class="body e-content">};
$post_template->spew( $post_template_content );
$plerd->publish_all;

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
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://www.example.com/blog' ),
);

$plerd->publish_all;
like ( Path::Class::File->new( $docroot_dir, 'recent.html' )->slurp,
     qr{http://www.example.com/blog/\d{4}-\d{2}-\d{2}-blah.html},
     'Base URIs missing trailing slashes work',
);

}

### Test using alternate config paths
{
$docroot_dir->rmtree;
$docroot_dir->mkpath;

my $alt_config_plerd = Plerd->new(
    source_path       => "$blog_dir/source",
    publication_path  => "$blog_dir/docroot",
    template_path     => "$blog_dir/templates",
    database_path     => "$blog_dir/db",
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
    path         => $blog_dir->stringify,
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
    path         => $blog_dir->stringify,
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
