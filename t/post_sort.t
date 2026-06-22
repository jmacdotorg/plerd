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

# Regression test for GitHub issue #50: the post list must come out in a
# deterministic order -- newest publication date first, ties broken by source
# basename -- even when the source directory mixes .md and .markdown files.
# This matches the ordering the incremental publisher derives from the post
# index (see Plerd::_ordered_basenames), so both code paths agree.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/post_sort_blog" );
$blog_dir->rmtree;
Plerd::Init::initialize( $blog_dir->stringify, 0 );

my $source_dir = Path::Class::Dir->new( $blog_dir, 'source' );

# Two posts share a date (forcing the basename tiebreak) and use different
# extensions; a third is older. Explicit timestamps keep dates exact.
my %sources = (
    '2020-06-20-bravo.md'        => '2020-06-20T10:00:00',
    '2020-06-20-alpha.markdown'  => '2020-06-20T10:00:00',
    '2019-01-01-charlie.md'      => '2019-01-01T10:00:00',
);
for my $basename ( keys %sources ) {
    Path::Class::File->new( $source_dir, $basename )->spew(
        iomode => '>:encoding(utf8)',
        "title: $basename\ntime: $sources{ $basename }\n\nBody.\n",
    );
}

my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new( 'http://blog.example.com/' ),
);

my @order = map { $_->source_file->basename } @{ $plerd->posts };

is_deeply(
    \@order,
    [
        '2020-06-20-alpha.markdown',  # same date as bravo, basename sorts first
        '2020-06-20-bravo.md',
        '2019-01-01-charlie.md',      # oldest, last
    ],
    'Posts sort newest-first with a stable basename tiebreak across extensions.'
);

$blog_dir->rmtree;

done_testing();
