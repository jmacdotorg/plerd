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

# Regression test for GitHub issue #25: source files that use CRLF ("Windows")
# newlines used to break publication with a misleading "not in W3C format"
# error. Plerd should accept CRLF source files, publish them cleanly, and
# normalize the rewritten source file to LF newlines.

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/crlf_testblog" );
$blog_dir->rmtree;

Plerd::Init::initialize( $blog_dir->stringify, 0 );

my $source_file = Path::Class::File->new( $blog_dir, 'source', 'crlf-post.md' );
{
    open my $fh, '>:raw', $source_file->stringify
        or die "Can't write $source_file: $!";
    print $fh "title: CRLF Post\r\n";
    print $fh "time: 2018-03-04T12:00:00\r\n";
    print $fh "tags: foo, bar\r\n";
    print $fh "\r\n";
    print $fh "This is the **body** of the post.\r\n";
    print $fh "\r\n";
    print $fh "Second paragraph here.\r\n";
    close $fh;
}

my $plerd = Plerd->new(
    path         => $blog_dir->stringify,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new( 'http://blog.example.com/' ),
);

eval { $plerd->publish_all; };
is( $@, '', 'A CRLF source file publishes without error.' );

my $published = Path::Class::File->new(
    $blog_dir, 'docroot', '2018-03-04-crlf-post.html'
);
ok( -e $published, 'The CRLF post produced its HTML file.' );

# The source file is rewritten in place during publication; it should no
# longer contain any carriage returns.
my $rewritten = do {
    open my $fh, '<:raw', $source_file->stringify or die $!;
    local $/;
    <$fh>;
};
unlike( $rewritten, qr/\r/, 'Rewritten source file is free of carriage returns.' );

$blog_dir->rmtree;

done_testing();
