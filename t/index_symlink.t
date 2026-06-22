use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use URI;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok( 'Plerd' );
use Plerd::Init;

# Regression test for GitHub issue #54: the docroot/index.html symlink must
# point at its sibling "recent.html" by basename, not at a path that includes
# the docroot directory. A target like "docroot/recent.html" resolves to
# docroot/docroot/recent.html from inside docroot and leaves index.html broken.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/index_symlink_blog" );
$blog_dir->rmtree;
Plerd::Init::initialize( $blog_dir->stringify, 0 );

Path::Class::File->new( $blog_dir, 'source', '2021-01-01-hello.md' )->spew(
    iomode => '>:encoding(utf8)',
    "title: Hello\n\nBody.\n",
);

my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new( 'http://blog.example.com/' ),
);

$plerd->publish_all;

my $index = Path::Class::File->new( $blog_dir, 'docroot', 'index.html' );

ok( -l $index, 'docroot/index.html is a symlink.' );
is( readlink( "$index" ), 'recent.html',
    'index.html points at its sibling recent.html by basename.' );
ok( -e $index, 'index.html resolves to an existing file.' );

$blog_dir->rmtree;

done_testing();
