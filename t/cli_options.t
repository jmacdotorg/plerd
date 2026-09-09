use warnings;
use strict;
use Test::More;
use Capture::Tiny ':all';

use FindBin;
use lib "$FindBin::Bin/../lib";

use Plerd;

my $plerdall = "$FindBin::Bin/../bin/plerdall";

# --version prints the Plerd version and exits zero, without requiring
# a config file to be present.
{
    my ($stdout, $stderr, $exit) = capture {
        system( $^X, '-I', "$FindBin::Bin/../lib/", $plerdall, '--version' );
    };

    is( $exit, 0, '--version exits zero.' );
    like(
        $stdout,
        qr/\Q$Plerd::VERSION\E/,
        '--version output mentions the Plerd version number.',
    );
    is( $stderr, '', '--version produces no error output.' );
}

# --help prints usage information and exits zero, without requiring
# a config file to be present.
{
    my ($stdout, $stderr, $exit) = capture {
        system( $^X, '-I', "$FindBin::Bin/../lib/", $plerdall, '--help' );
    };

    is( $exit, 0, '--help exits zero.' );
    like(
        $stdout,
        qr/plerdall/i,
        '--help output mentions the program name.',
    );
    like(
        $stdout,
        qr/--config/,
        '--help output documents the --config option.',
    );
    is( $stderr, '', '--help produces no error output.' );
}

# An unrecognized option should still fail informatively (regression
# check for the old "Unknown option: help"-with-a-config-error mess).
{
    my ($stdout, $stderr, $exit) = capture {
        system(
            $^X, '-I', "$FindBin::Bin/../lib/",
            $plerdall, '--this-is-not-a-real-option',
        );
    };

    isnt( $exit, 0, 'An unrecognized option exits non-zero.' );
}

# plerdwatcher --version prints the Plerd version and exits zero,
# without requiring a config file or launching the daemon.
{
    my $plerdwatcher = "$FindBin::Bin/../bin/plerdwatcher";

    my ($stdout, $stderr, $exit) = capture {
        system( $^X, '-I', "$FindBin::Bin/../lib/", $plerdwatcher, '--version' );
    };

    is( $exit, 0, 'plerdwatcher --version exits zero.' );
    like(
        $stdout,
        qr/\Q$Plerd::VERSION\E/,
        'plerdwatcher --version output mentions the Plerd version number.',
    );
    is( $stderr, '', 'plerdwatcher --version produces no error output.' );
}

# plerdwatcher --help prints usage information and exits zero, without
# requiring a config file or launching the daemon.
{
    my $plerdwatcher = "$FindBin::Bin/../bin/plerdwatcher";

    my ($stdout, $stderr, $exit) = capture {
        system( $^X, '-I', "$FindBin::Bin/../lib/", $plerdwatcher, '--help' );
    };

    is( $exit, 0, 'plerdwatcher --help exits zero.' );
    like(
        $stdout,
        qr/plerdwatcher/i,
        'plerdwatcher --help output mentions the program name.',
    );
    like(
        $stdout,
        qr/--config/,
        'plerdwatcher --help output documents the --config option.',
    );
    is( $stderr, '', 'plerdwatcher --help produces no error output.' );
}

done_testing;