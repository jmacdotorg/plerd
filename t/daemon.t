use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use URI;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plerd::Init;

my $blog_dir = Path::Class::Dir->new( "$FindBin::Bin/testblog" );
$blog_dir->rmtree;

my $init_messages_ref = Plerd::Init::initialize( $blog_dir->stringify, 0 );
unless (-e $blog_dir) {
    die "Failed to create $blog_dir: @$init_messages_ref\n";
}

my $now = DateTime->now( time_zone => 'local' );
my $ymd = $now->ymd;

my $model_dir = Path::Class::Dir->new( "$FindBin::Bin/source_model" );
my $source_dir = Path::Class::Dir->new( $blog_dir, 'source' );
my $docroot_dir = Path::Class::Dir->new( $blog_dir, 'docroot' );

# Just copy over one good-to-go source file from the model, for this test.
my $good_model_file = Path::Class::File->new(
    $model_dir,
    'good-source-file.md',
);
my $good_source_file = Path::Class::File->new(
    $source_dir,
    'good-source-file.md',
);
$good_model_file->copy_to( $good_source_file );

my $daemon = "$FindBin::Bin/../bin/plerdwatcher";

# Write out a config file for this test.
my $config_file_path = Path::Class::File->new(
    $FindBin::Bin,
    'test.conf',
);

my $run_dir_path = Path::Class::Dir->new(
    $FindBin::Bin,
    'run',
);
my $log_dir_path = Path::Class::Dir->new(
    $FindBin::Bin,
    'log',
);

my $config = <<"END";
base_uri:      http://plerd.example.com/
path:          $blog_dir
title:         My Cool Blog
author_name:   Sam Handwich
author_email:  s.handwich\@example.com
END

$config_file_path->spew( $config );

system(
    $^X,
    '-I', "$FindBin::Bin/../lib/",
    $daemon,
    "--config=$config_file_path",
    'start',
);

my $plerd_pid = Path::Class::File->new( $blog_dir, 'run', 'plerdwatcher.pid' );
unless (-e $plerd_pid) {
    die "Tried to launch a plerdwatcher test instance, but no PID file found.";
}

my $pid = Path::Class::File->new( $plerd_pid )->slurp;
chomp $pid;

# Give the new process a few seconds to gather itself...
diag "Giving the Plerd daemon a few seconds to spin up...";
sleep(5);

# Now edit one source file, and see if the docroot populates.
open (my $fh, '>>', $good_source_file)
    or quit( "Can't modify $good_source_file for testing: $!" );
print $fh "\nHello!\n";
close $fh or quit( "Couldn't close $good_source_file for testing: $!" );

# This shouldn't take more than a couple of seconds to update...
diag "Giving the Plerd daemon a few seconds to process a change...";
sleep(5);

# Magic number "7" below accounts for the 1 post plus various auto-generated
# files.
is ( $docroot_dir->children( visible => 1 ), 7, "Success!" );

kill ('KILL', $pid) or die "Could not kill test plerdwatcher instance ($pid): $!";
done_testing();

sub quit {
    my ( $message ) = @_;
    kill ('KILL', $pid)
        or die "Could not kill test plerdwatcher instance ($pid): $!";
    if ( $message ) {
        die $message;
    }
}
