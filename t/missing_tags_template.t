use warnings;
use strict;
use Test::More;
use Test::Warn;
use Path::Class::Dir;
use Path::Class::File;
use URI;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok( 'Plerd' );
use Plerd::Init;

# Regression test for GitHub issue #41: tags.tt is the one non-critical
# template. If it's missing, the blog should still publish. It should publish
# silently when the blog has no tags, and warn (rather than die) when the blog
# does use tags but can't render their pages.

sub fresh_blog {
    my ( $name ) = @_;
    my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/$name" );
    $blog_dir->rmtree;
    Plerd::Init::initialize( $blog_dir->stringify, 0 );

    # Remove the tags template to simulate a blog that lacks it.
    Path::Class::File->new( $blog_dir, 'templates', 'tags.tt' )->remove;

    my $plerd = Plerd->new(
        path         => $blog_dir->stringify,
        title        => 'Test Blog',
        author_name  => 'Nobody',
        author_email => 'nobody@example.com',
        base_uri     => URI->new( 'http://blog.example.com/' ),
    );
    return ( $blog_dir, $plerd );
}

# Case 1: a blog with no tags at all.
{
    my ( $blog_dir, $plerd ) = fresh_blog( 'no_tags_blog' );
    my $source = Path::Class::File->new( $blog_dir, 'source', '2018-01-01-hello.md' );
    $source->spew( iomode => '>:encoding(utf8)', "title: Hello\n\nNo tags here.\n" );

    warning_is { eval { $plerd->publish_all } } undef,
        'Publishing a tag-free blog without tags.tt produces no warning.';
    is( $@, '', 'Publishing a tag-free blog without tags.tt does not die.' );
    ok(
        -e Path::Class::File->new( $blog_dir, 'docroot', '2018-01-01-hello.html' ),
        'The post still published.'
    );

    $blog_dir->rmtree;
}

# Case 2: a blog that does use tags.
{
    my ( $blog_dir, $plerd ) = fresh_blog( 'tagged_blog' );
    my $source = Path::Class::File->new( $blog_dir, 'source', '2018-01-02-tagged.md' );
    $source->spew(
        iomode => '>:encoding(utf8)',
        "title: Tagged\ntags: foo, bar\n\nThis post has tags.\n"
    );

    warning_like { eval { $plerd->publish_all } } qr/tags\.tt/,
        'Publishing a tagged blog without tags.tt warns about the missing template.';
    is( $@, '', 'Publishing a tagged blog without tags.tt does not die.' );
    ok(
        -e Path::Class::File->new( $blog_dir, 'docroot', '2018-01-02-tagged.html' ),
        'The post still published.'
    );

    $blog_dir->rmtree;
}

done_testing();
