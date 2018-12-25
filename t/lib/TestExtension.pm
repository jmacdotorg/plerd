package TestExtension;
use Plerd::Post;
use Moose;
use strict;

use 5.010;

use warnings FATAL => 'all';

extends "Plerd::Post";

sub file_type {
    'dm';
}

around 'body' => sub {
    my $orig = shift;
    my $self = shift;
    if (@_){
        # "Setter"
        my $body = shift;

        # first time body is called, reverse it!
        $body = reverse $body unless $self->$orig;

        $self->$orig($body);
    } else {
        # "Getter"
        $self->$orig();
    }
};

1;


=head1 NAME

TestExtension - A L<Plerd::Post> extension to showcase the extension capabilities of L<Plerd>.

=head1 DESCRIPTION

This extension doesn't do anything truly useful. It's sole purpose is showcasing the extension capabilities.

What it does in fact do, though, is reversing the body of the document (the first time it's set).

It's rather useless.

=head1 OBJECT ATTRIBUTES

=head2 Read-only attributes, set during construction

=over

=item file_type

A regex-compatible string which indicate what file types to associate with the Extension.
This is set to "dm" (which happens to be "md" spelled backwards)

=item body

The original L<Plerd::Post> body, except that the first time this attribute is set, it gets reversed.

=back

=head2 Other attributes

All other attributes are inherited from L<Plerd::Post> Please consult that documentation for their docs.

