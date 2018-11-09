package TestExtension;
use Plerd::Post;
use Moose;
use strict;
use warnings FATAL => 'all';

extends "Plerd::Post";

sub file_type {
    'dm';
}

1;
