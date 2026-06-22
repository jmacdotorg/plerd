use warnings;
use strict;
use utf8;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use URI;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok( 'Plerd' );
use Plerd::Init;

# Regression test for GitHub issue #52: a post titled entirely with
# characters that can't appear in a filename (e.g. emoji) used to slug down
# to nothing, so every such post on a given day collided on
# "YYYY-MM-DD-.html" and overwrote its predecessor. Distinct titles must
# produce distinct, non-empty published filenames.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/emoji_title_blog" );
$blog_dir->rmtree;
Plerd::Init::initialize( $blog_dir->stringify, 0 );

my $source_dir = Path::Class::Dir->new( $blog_dir, 'source' );

# Two emoji-only titles, same publication day, source filenames carry no date
# prefix so the title-based filename logic runs.
Path::Class::File->new( $source_dir, 'smile.md' )->spew(
    iomode => '>:encoding(utf8)',
    "title: \x{1F600}\ntime: 2021-01-19T10:00:00\n\nBody one.\n",
);
Path::Class::File->new( $source_dir, 'hats.md' )->spew(
    iomode => '>:encoding(utf8)',
    "title: \x{1F3A9}\x{1F3A9}\ntime: 2021-01-19T11:00:00\n\nBody two.\n",
);

my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new( 'http://blog.example.com/' ),
);

$plerd->publish_all;

my %filename;
for my $post ( @{ $plerd->posts } ) {
    $filename{ $post->title } = $post->published_filename;
}

my @names = values %filename;
isnt( $names[0], $names[1],
    'Two emoji-only titles get distinct published filenames.' );

unlike( $_, qr/-\.html$/, 'Published filename is not empty-slugged.' )
    for @names;

# Both posts' HTML files should actually exist on disk (neither overwrote the
# other).
for my $title ( keys %filename ) {
    ok(
        -e Path::Class::File->new( $blog_dir, 'docroot', $filename{ $title } ),
        "HTML file exists for title '$title' ($filename{ $title })."
    );
}

$blog_dir->rmtree;

done_testing();
