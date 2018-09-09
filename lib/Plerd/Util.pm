package Plerd::Util;

# This is just some utility functions for Plerd, with no intended public API.

use warnings;
use strict;
use Try::Tiny;
use File::HomeDir;
use YAML qw( LoadFile );
use Cwd;

# read_config_file: Pass in a param representing a config file location, which
#                   can be undef if we don't have one. Apply fallbacks if
#                   needed, then try to parse it as YAML and return the
#                   resulting data structure.
sub read_config_file {
    my ( $config_file ) = @_;

    unless ( defined $config_file ) {
        # As fallback config locations, try ./plerd.conf, and then
        # ~/.plerd, then (for historical reasons)
        # $bin/../conf/plerd.conf. Then give up.
        my $local_file = Path::Class::File->new( getcwd, 'plerd.conf' );
        my $dotfile = Path::Class::File->new( File::HomeDir->my_home, '.plerd' );
        foreach (
            $local_file,
            $dotfile,
            "$FindBin::Bin/../conf/plerd.conf",
        ) {
            if ( -r $_ ) {
                $config_file = $_;
                last;
            }
        }
        unless ( defined $config_file ) {
            die "Can't start $0: I can't find a Plerd config file in "
                . "$local_file, $dotfile, or in "
                . "$FindBin::Bin/../conf/plerd.conf, and "
                . "no other location was specified as a command-line argument.";
        }
    }

    my $config_ref;
    try {
        $config_ref = LoadFile( $config_file );
    }
    catch {
        if ( -r $config_file ) {
            die "Can't start $0: Can't read config file at $config_file: $_\n";
        }
        else {
            die "Can't start $0: No readable config file found at $config_file.\n";
        }
    };
}

1;
