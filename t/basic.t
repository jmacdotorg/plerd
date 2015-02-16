use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use URI;

use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok( 'Plerd' );

# Prepare by making a fresh source directory, based on the source_model directory
# (and throw out said source dir if it's already there from e.g. a botched test)
my $source_dir = Path::Class::Dir->new( "$FindBin::Bin/source" );
$source_dir->rmtree;
$source_dir->mkpath;

my $model_dir = Path::Class::Dir->new( "$FindBin::Bin/source_model" );
foreach ( Path::Class::Dir->new( "$FindBin::Bin/source_model" )->children ) {
    $_->copy_to( $source_dir );
}

# And then clean out the docroot.
my $docroot_dir = Path::Class::Dir->new( "$FindBin::Bin/docroot" );
foreach ( $docroot_dir->children ) {
    $_->remove;
}

# Now try to make a Plerd object, and send it through its paces.
my $plerd = Plerd->new(
    path         => $FindBin::Bin,
    title        => 'Test Blog',
    author_name  => 'Nobody',
    author_email => 'nobody@example.com',
    base_uri     => URI->new ( 'http://blog.example.com/' ),
);

eval { $plerd->publish_all; };
like ( $@, qr/Invalid W3CDTF/, 'Rejected source file with invalid timestamp.' );

unlink "$FindBin::Bin/source/bad-date.md";

eval { $plerd->publish_all; };
like ( $@, qr/post title/, 'Rejected title-free source file.' );

unlink "$FindBin::Bin/source/no-title.md";

$plerd->publish_all;

is( scalar( $docroot_dir->children ), 6, "Correct number of HTML files generated." );

done_testing();
