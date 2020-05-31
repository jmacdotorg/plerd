package Plerd::Util;

# This is just some utility functions for Plerd, with no intended public API.

use warnings;
use strict;
use Try::Tiny;
use File::HomeDir;
use YAML qw( LoadFile );
use Cwd;
use Path::Class::File;

# read_config_file: Pass in a param representing a config file location, which
#                   can be undef if we don't have one. Apply fallbacks if
#                   needed, then try to parse it as YAML and return the
#                   resulting data structure.
sub read_config_file {
    my ($config_file) = @_;

    unless (defined $config_file) {
        # As fallback config locations, try ./plerd.conf, conf/plerd.conf,
        # ~/.plerd, then (for historical reasons) $bin/../conf/plerd.conf.
        # Then give up.
        my $local_file  = Path::Class::File->new(getcwd,                 'plerd.conf');
        my $nearby_file = Path::Class::File->new(getcwd,                 'conf', 'plerd.conf');
        my $dotfile     = Path::Class::File->new(File::HomeDir->my_home, '.plerd');
        foreach ($local_file, $nearby_file, $dotfile, "$FindBin::Bin/../conf/plerd.conf",) {
            if (-r $_) {
                $config_file = $_;
                last;
            }
        }
        unless (defined $config_file) {
            die "Can't start $0: I can't find a Plerd config file in "
                . "$local_file, $nearby_file, $dotfile, or in "
                . "$FindBin::Bin/../conf/plerd.conf, and "
                . "no other location was specified as a command-line argument.";
        }
    }

    my $config_ref;
    try {
        $config_ref = LoadFile($config_file);
    }
    catch {
        if (-r $config_file) {
            die "Can't start $0: Can't read config file at $config_file: $_\n";
        } else {
            die "Can't start $0: No readable config file found at $config_file.\n";
        }
    };
    return;
}

1;

=head1 NAME

Plerd::Util

=head1 DESCRIPTION

This class provides some utility functions common to Plerd's
command-line programs. It has no public API.

=head1 SEE ALSO

L<Plerd>

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
