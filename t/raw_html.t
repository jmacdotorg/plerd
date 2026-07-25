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

# GitHub-Flavored Markdown's "tagfilter" extension escapes a handful of raw
# tags -- iframe, script, style, and friends -- because GitHub renders
# untrusted input. A Plerd blog renders its author's own source files, so
# Plerd's converter turns the filter off and passes these tags through.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/raw_html_blog" );
$blog_dir->rmtree;
Plerd::Init::initialize( $blog_dir->stringify, 0 );

my $source = <<'END';
title: Raw HTML

An embedded video:

<iframe width="560" height="315" src="https://www.example.com/embed/abc" title="A Video" allowfullscreen></iframe>

Some behavior:

<script>var x = 1 < 2;</script>

Some style:

<style>p { color: red }</style>

A paragraph with an <iframe src="https://www.example.com/embed/def"></iframe> inline.

A "quoted phrase" outside of any tag.
END

Path::Class::File->new( $blog_dir, 'source', '2022-07-31-raw-html.md' )->spew(
    iomode => '>:encoding(utf8)', $source,
);

my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new( 'http://blog.example.com/' ),
);

$plerd->publish_all;
my ( $post ) = @{ $plerd->posts };
my $body = $post->body;

unlike( $body, qr{&lt;iframe},
    'A block-level <iframe> is not escaped.' );
like( $body, qr{<iframe width="560" height="315" src="https://www\.example\.com/embed/abc" title="A Video" allowfullscreen></iframe>},
    'A block-level <iframe> passes through with its attributes intact.' );
like( $body, qr{<script>var x = 1 < 2;</script>},
    'A <script> element passes through verbatim.' );
like( $body, qr{<style>p \{ color: red \}</style>},
    'A <style> element passes through verbatim.' );
like( $body, qr{an <iframe src="https://www\.example\.com/embed/def"></iframe> inline},
    'An inline <iframe> passes through.' );
like( $body, qr{\x{201c}quoted phrase\x{201d}},
    'SmartyPants still curls quotes in prose.' );

my $output = Path::Class::File->new(
    $blog_dir, 'docroot', '2022-07-31-raw-html.html'
)->slurp( iomode => '<:encoding(utf8)' );

like( $output, qr{<iframe width="560"},
    'The published page contains the unescaped <iframe>.' );

$blog_dir->rmtree;

done_testing();
