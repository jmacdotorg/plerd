package Plerd::Webmention::Author;

use Moose;
use MooseX::Types::URI qw(Uri);
use Try::Tiny;
use LWP::UserAgent;
use List::Util qw(first);

use Plerd::Microformats2::Parser;

has 'name' => (
    is => 'ro',
    isa => 'Str',
);

has 'url' => (
    is => 'ro',
    isa => Uri,
    coerce => 1,
);

has 'photo' => (
    is => 'ro',
    isa => Uri,
    coerce => 1,
);

sub new_from_html {
    my $class = shift;
    my ($html) = @_;

    # This method implements the Indieweb Authorship Algorithm.
    # https://indieweb.org/authorship#How_to_determine
    # The quoted comments below are direct quotes from that page
    # (as of spring 2018).

    # "Start with a particular h-entry to determine authorship for,
    # and no author."

    my $author;
    my $author_page;

    my $parser = Plerd::Microformats2::Parser->new;
    my $doc = $parser->parse( $html );

    my $h_entry = $doc->get_first( 'h-entry' );

    # "If no h-entry, then there's no post to find authorship for, abort."
    unless ( $h_entry ) {
        return;
    }

    # "If the h-entry has an author property, use that."
    $author = $h_entry->get_property( 'author' );

    # "Otherwise if the h-entry has a parent h-feed with author property,
    # use that."
    if (
        not ( $author )
        && $h_entry->parent
        && ( $h_entry->parent->type eq 'h-feed' )
    ) {
        $author = $h_entry->parent->get_property( 'author' );
    }

    # "If an author property was found:"

    #   "If it has an h-card, use it, exit."
    if (
        defined $author
        && blessed( $author )
        && ( $author->has_type( 'h-card' ) )
    ) {
        return $class->_new_with_h_card( $author );
    }

    #   "Otherwise if author property is an http(s) URL,
    #   let the author-page have that URL."
    if ( defined $author ) {
        try {
            $author_page = URI->new( $author );
            unless ( $author_page->schema =~ /^http/ ) {
                undef $author_page;
            }
        };
    }

    #   "Otherwise use the author property as the author name, exit."
    unless ( $author_page ) {
        return $class->new( name => $author );
    }

    # "If there is an author-page URL:"

    #   "Get the author-page from that URL and parse it for Microformats-2."
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get( $author_page );
    my $author_doc = $parser->parse( $response );

    #   "If author-page has 1+ h-card with url == uid == author-page's URL,
    #   then use first such h-card, exit."
    my @h_cards = $doc->get_all( 'h-cards' );
    for my $h_card ( @h_cards ) {
        my $urls_ref = $h_card->get_properties( 'url' );
        my $uids_ref = $h_card->get_properties( 'uid' );
        if (
            first { $_ eq $author_page->as_string } @$urls_ref
            && first { $_ eq $author_page->as_string } @$uids_ref
        ) {
            return $class->_new_with_h_card( $h_card );
        }
    }

    # XXX Skipping the "rel-me"-based test.

    #   "if the h-entry's page has 1+ h-card with url == author-page URL,
    #   use first such h-card, exit."
    for my $h_card ( @h_cards ) {
        my $urls_ref = $h_card->get_properties( 'url' );
        if (
            first { $_ eq $author_page->as_string } @$urls_ref
        ) {
            return $class->_new_with_h_card( $h_card );
        }
    }

}

sub _new_with_h_card {
    my ( $class, $h_card ) = @_;

    my %constructor_args;

    foreach ( qw (name url photo ) ) {
        $constructor_args{ $_ } = $h_card->get_property( $_ );
    }

    return $class->new( %constructor_args );
}


1;
