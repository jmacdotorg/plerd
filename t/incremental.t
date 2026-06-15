use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use URI;
use JSON;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok( 'Plerd' );

use Plerd::Init;

# A body-only edit to a post that is NOT in the recent set should touch exactly
# one output file (that post's own page) and rebuild nothing else. A body-only
# edit to a post that IS in the recent set should additionally refresh the
# recent page and feeds -- but still not the archive, and still not re-render
# the whole blog. We pin recent_posts_maxsize low so "recent" vs "not recent"
# is deterministic regardless of how many fixtures exist.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/testblog_incremental" );
$blog_dir->rmtree;

my $init_messages_ref = Plerd::Init::initialize( $blog_dir->stringify, 0 );
unless (-e $blog_dir) {
    die "Failed to create $blog_dir: @$init_messages_ref\n";
}

my $source_dir  = Path::Class::Dir->new( $blog_dir, 'source' );
my $docroot_dir = Path::Class::Dir->new( $blog_dir, 'docroot' );

# Four posts with distinct, hard-coded dates. Newest-first: d, c, b, a.
my %source;
for my $spec ( [ a => '2020-01-01' ], [ b => '2020-02-01' ],
               [ c => '2020-03-01' ], [ d => '2020-04-01' ] )
{
    my ( $name, $date ) = @$spec;
    my $file = Path::Class::File->new( $source_dir, "$date-$name.md" );
    $file->spew( iomode => '>:encoding(utf8)',
        "title: Post $name\n\nThe original body of post $name.\n" );
    $source{ $name } = $file;
}

my $plerd = Plerd->new(
    path                 => $blog_dir->stringify,
    title                => 'Test Blog',
    author_name          => 'Nobody',
    author_email         => 'nobody@example.com',
    base_uri             => URI->new( 'http://blog.example.com/' ),
    recent_posts_maxsize => 2,    # recent set is { d, c }; { b, a } are not.
);

# Seed everything: first publish_file finds no index, so it publishes the whole
# blog and records the index.
$plerd->publish_file( $source{ a } );

my %html = map {
    $_ => Path::Class::File->new( $docroot_dir, "2020-0$_-01-$_.html" )
} ( 1 .. 4 );    # not used directly; real names built below
my $page = sub {
    my ( $name, $month ) = @_;
    Path::Class::File->new( $docroot_dir, "2020-$month-01-$name.html" );
};
my $a_html = $page->( 'a', '01' );
my $b_html = $page->( 'b', '02' );
my $c_html = $page->( 'c', '03' );
my $d_html = $page->( 'd', '04' );

my $recent  = Path::Class::File->new( $docroot_dir, 'recent.html' );
my $atom    = Path::Class::File->new( $docroot_dir, 'atom.xml' );
my $json    = Path::Class::File->new( $docroot_dir, 'feed.json' );
my $archive = Path::Class::File->new( $docroot_dir, 'archive.html' );

### The index records a per-post object with hash + time, not a bare hash.
{
    my $index = JSON->new->decode(
        scalar Path::Class::File->new( $blog_dir, 'db', 'posts.json' )
            ->slurp( iomode => '<:encoding(utf8)' ) );
    my $record = $index->{ '2020-01-01-a.md' };
    is( ref $record, 'HASH', 'posts.json stores a record object per post.' );
    ok( $record->{ hash }, 'Index record has a metadata hash.' );
    ok( $record->{ time }, 'Index record has a publication time.' );
}

sub mtimes_of { return map { $_->stat->mtime } @_ }

### Body-only edit of a NON-recent post (a): only its page should change.
{
    my @before = mtimes_of( $recent, $atom, $json, $archive, $b_html, $d_html );
    my $a_before = $a_html->stat->mtime;
    sleep 1;    # mtime resolution is 1 second.

    my $content = $source{ a }->slurp( iomode => '<:encoding(utf8)' );
    $content =~ s/The original body of post a\./A freshly edited body for a./;
    $source{ a }->spew( iomode => '>:encoding(utf8)', $content );

    $plerd->publish_file( $source{ a } );

    isnt( $a_html->stat->mtime, $a_before,
        'The edited post page is rewritten.' );
    like( $a_html->slurp( iomode => '<:encoding(utf8)' ),
        qr/A freshly edited body for a\./,
        'The edited post page shows the new body.' );

    my @after = mtimes_of( $recent, $atom, $json, $archive, $b_html, $d_html );
    is_deeply( \@after, \@before,
        'A non-recent body edit rewrites no other file (recent, feeds, '
        . 'archive, and other post pages all untouched).' );
}

### Prev/next navigation on an incrementally published page stays correct.
{
    my $content = $source{ b }->slurp( iomode => '<:encoding(utf8)' );
    $content =~ s/The original body of post b\./Edited body for b./;
    $source{ b }->spew( iomode => '>:encoding(utf8)', $content );

    $plerd->publish_file( $source{ b } );

    my $b_content = $b_html->slurp( iomode => '<:encoding(utf8)' );
    like( $b_content, qr/2020-03-01-c\.html/,
        'Incrementally published page links to the newer neighbor (c).' );
    like( $b_content, qr/2020-01-01-a\.html/,
        'Incrementally published page links to the older neighbor (a).' );
}

### Body-only edit of a RECENT post (d): refresh its page + recent + feeds,
### but not the archive, and not the unrelated non-recent pages.
{
    my @before = mtimes_of( $archive, $a_html );
    my @feed_before = mtimes_of( $recent, $atom, $json );
    my $d_before = $d_html->stat->mtime;
    sleep 1;

    my $content = $source{ d }->slurp( iomode => '<:encoding(utf8)' );
    $content =~ s/The original body of post d\./Edited body for d./;
    $source{ d }->spew( iomode => '>:encoding(utf8)', $content );

    $plerd->publish_file( $source{ d } );

    isnt( $d_html->stat->mtime, $d_before, 'The recent post page is rewritten.' );

    my @feed_after = mtimes_of( $recent, $atom, $json );
    isnt( "@feed_after", "@feed_before",
        'A recent body edit refreshes the recent page and feeds.' );

    my @after = mtimes_of( $archive, $a_html );
    is_deeply( \@after, \@before,
        'A recent body edit leaves the archive and unrelated pages untouched.' );
}

$blog_dir->rmtree;

done_testing();
