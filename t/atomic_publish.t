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

# Publishing must be atomic: a web server should never see a half-written or
# zero-length output file, and a publish that dies partway through must leave
# the previously published file untouched. We prove that here by deliberately
# breaking a template after a good publish, then confirming the already-
# published files still hold their original content.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/testblog_atomic" );
$blog_dir->rmtree;

my $init_messages_ref = Plerd::Init::initialize( $blog_dir->stringify, 0 );
unless (-e $blog_dir) {
    die "Failed to create $blog_dir: @$init_messages_ref\n";
}

my $source_dir  = Path::Class::Dir->new( $blog_dir, 'source' );
my $docroot_dir = Path::Class::Dir->new( $blog_dir, 'docroot' );

# A couple of minimal, valid source files so there's something to publish.
Path::Class::File->new( $source_dir, '2020-01-01-first.md' )->spew(
    iomode => '>:encoding(utf8)',
    "title: First post\n\nThe original first body.\n",
);
Path::Class::File->new( $source_dir, '2020-02-02-second.md' )->spew(
    iomode => '>:encoding(utf8)',
    "title: Second post\n\nThe original second body.\n",
);

my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new( 'http://blog.example.com/' ),
);

$plerd->publish_all;

my $recent_file = Path::Class::File->new( $docroot_dir, 'recent.html' );
my $post_file   = Path::Class::File->new( $docroot_dir, '2020-01-01-first.html' );

my $original_recent = $recent_file->slurp( iomode => '<:encoding(utf8)' );
my $original_post   = $post_file->slurp( iomode => '<:encoding(utf8)' );

ok( length $original_recent, 'recent.html has content after a good publish.' );
ok( length $original_post,   'A post page has content after a good publish.' );

# Sabotage the post template so the next render throws partway through.
my $post_template =
    Path::Class::File->new( $blog_dir, 'templates', 'post.tt' );
$post_template->spew(
    iomode => '>:encoding(utf8)',
    qq{Some output before the explosion.\n[% THROW boom 'deliberate test failure' %]\n},
);

# Republishing the recent page now fails. The existing recent.html must be
# left exactly as it was, not truncated or partially overwritten.
eval { $plerd->publish_recent_page };
ok( $@, 'A broken template makes publish_recent_page die.' );
is( $recent_file->slurp( iomode => '<:encoding(utf8)' ),
    $original_recent,
    'A failed publish leaves the existing recent.html intact (atomic write).',
);

# Same guarantee for an individual post page via Plerd::Post::publish.
my $post = $plerd->posts->[0];
eval { $post->publish };
ok( $@, 'A broken template makes a post publish die.' );
is( $post_file->slurp( iomode => '<:encoding(utf8)' ),
    $original_post,
    'A failed publish leaves the existing post page intact (atomic write).',
);

$blog_dir->rmtree;

done_testing();
