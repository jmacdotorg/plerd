package Plerd::Tag;

use Moose;
use URI;

has 'plerd' => (
    is => 'ro',
    required => 1,
    isa => 'Plerd',
    weak_ref => 1,
);

has 'posts' => (
    is => 'ro',
    isa => 'ArrayRef[Plerd::Post]',
    default => sub { [] },
);

has 'name' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'uri' => (
    is => 'ro',
    isa => 'URI',
    lazy_build => 1,
);

sub add_post {
    my ($self, $post) = @_;

    push ( @{$self->posts}, $post );
}

sub ponder_new_name {
    my ($self, $new_name) = @_;

    my $current_name = $self->name;

    if ( $current_name eq $new_name ) {
        return;
    }
    elsif ( not ($current_name =~ /[[:upper:]]/) ) {
        $self->name( $new_name );
    }
}

sub _build_uri {
    my $self = shift;

    return URI->new_abs(
        'tags/' . $self->name . '.html',
        $self->plerd->base_uri,
    );
}

1;

=head1 NAME

Plerd::Tag

=head1 DESCRIPTION

Objects of this class represent a categorization tag in a Plerd blog.

=head1 CLASS METHODS

=over

=item new( \%config )

Object constructor. The single config hashref I<must> include the
following keys:

=over

=item plerd

The parent Plerd object.

=item name

This tag's name. Just an ordinary text string.

=back


=head1 ATTRIBUTES

=over

=item posts

A list reference of all L<Plerd::Post> objects making use of this tag.

=item uri

A L<URI> object pointing to this tag's detail page.

=back

=head1 OBJECT METHODS

=over

=item ponder_new_name ( $new_name )

Given $new_name, this tag ponders whether it should replace its own name
with it. If it decides that that a replacement is due, it goes ahead and
performs the swap.

If the current name has no capital letters, and the new name does, then
the new name will indeed replace it.

For example, if a tag is named "foo", and we call this method with
"Foo", then this tag will rename itself to "Foo". If we call it again
with "foo", the tag will remain "Foo".

=back

=head1 SEE ALSO

L<Plerd>

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
