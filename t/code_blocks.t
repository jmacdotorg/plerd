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

# Regression test for GitHub issue #57: GitHub-style fenced code blocks.
# Text::MultiMarkdown does not understand ``` or ~~~ fences -- it collapsed a
# backtick-fenced block into a single inline <code> span (so every line
# wrapped together) and ignored ~~~ entirely. Plerd now pre-processes fences
# into <pre><code> blocks before handing the body to Markdown.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/code_blocks_blog" );
$blog_dir->rmtree;
Plerd::Init::initialize( $blog_dir->stringify, 0 );

my $source = <<'END';
title: Code

Backtick fence with a language:

```perl
my $x = 1;
if ( $x < 2 ) { say "ok"; }
```

Tilde fence:

~~~
plain text
second line
~~~

Inline `code` is untouched.
END

Path::Class::File->new( $blog_dir, 'source', '2022-07-31-code.md' )->spew(
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

like( $body, qr{<pre><code class="language-perl">},
    'Backtick fence becomes a <pre><code> block with a language class.' );
like( $body, qr{my \$x = 1;\nif},
    'Code lines are preserved on separate lines, not wrapped together.' );
like( $body, qr{\$x &lt; 2},
    'Code special characters are HTML-escaped.' );
like( $body, qr{<pre><code>\s*plain text\nsecond line},
    'Tilde fence also becomes a <pre><code> block.' );
like( $body, qr{<code>code</code>},
    'Inline code spans still work.' );
unlike( $body, qr{<p><code>perl},
    'Fence is not collapsed into a single inline code span.' );

$blog_dir->rmtree;

done_testing();
