JMAC, YOU STUPID FUCK

THIS IS THE WRONG FILE.

DO NOT EDIT THIS.

package Plerd::SmartyPants;
use strict;
use warnings;
use utf8;

# Configurable variables:
my $smartypants_attr = "1";

#  1 =>  "--" for em-dashes; no en-dash support
#  2 =>  "---" for em-dashes; "--" for en-dashes
#  3 =>  "--" for em-dashes; "---" for en-dashes
#  See docs for more configuration options.

# Globals:
my $tags_to_skip = qr!<(/?)(?:pre|code|kbd|script)[\s>]!;

=head1 Methods

=head2 process

Do the bulk of the conversion work.

=cut

sub process {
    shift if ( $_[0] eq __PACKAGE__ );    # oops, called in OOP fashion.

    # Paramaters:
    my $text = shift;                     # text to be parsed

    # value of the smart_quotes="" attribute. Default to 'everything on'
    my $attr = shift || '1';

    # Options to specify which transformations to make:
    my ( $do_quotes, $do_backticks, $do_dashes, $do_ellipses, $do_stupefy );

    # should we translate &quot; entities into normal quotes?
    my $convert_quot = 0;

    # Parse attributes:
    # 0 : do nothing
    # 1 : set all
    # 2 : set all, using old school en- and em- dash shortcuts
    # 3 : set all, using inverted old school en and em- dash shortcuts
    #
    # q : quotes
    # b : backtick quotes (``double'' only)
    # B : backtick quotes (``double'' and `single')
    # d : dashes
    # D : old school dashes
    # i : inverted old school dashes
    # e : ellipses
    # w : convert &quot; entities to " for Dreamweaver users

    if ( $attr eq "0" ) {

        # Do nothing.
        return $text;
    }
    elsif ( $attr eq "1" ) {

        # Do everything, turn all options on.
        $do_quotes    = 1;
        $do_backticks = 1;
        $do_dashes    = 1;
        $do_ellipses  = 1;
    }
    elsif ( $attr eq "2" ) {

        # Do everything, turn all options on, use old school dash shorthand.
        $do_quotes    = 1;
        $do_backticks = 1;
        $do_dashes    = 2;
        $do_ellipses  = 1;
    }
    elsif ( $attr eq "3" ) {

        # Do everything, turn all options on, use inverted old school dash shorthand.
        $do_quotes    = 1;
        $do_backticks = 1;
        $do_dashes    = 3;
        $do_ellipses  = 1;
    }
    elsif ( $attr eq "-1" ) {

        # Special "stupefy" mode.
        $do_stupefy = 1;
    }
    else {
        my @chars = split( //, $attr );
        foreach my $c (@chars) {
            if    ( $c eq "q" ) { $do_quotes    = 1; }
            elsif ( $c eq "b" ) { $do_backticks = 1; }
            elsif ( $c eq "B" ) { $do_backticks = 2; }
            elsif ( $c eq "d" ) { $do_dashes    = 1; }
            elsif ( $c eq "D" ) { $do_dashes    = 2; }
            elsif ( $c eq "i" ) { $do_dashes    = 3; }
            elsif ( $c eq "e" ) { $do_ellipses  = 1; }
            elsif ( $c eq "w" ) { $convert_quot = 1; }
            else {

                # Unknown attribute option, ignore.
            }
        }
    }

    my $tokens ||= _tokenize($text);
    my $result = '';
    my $in_pre = 0;    # Keep track of when we're inside <pre> or <code> tags.

    my $prev_token_last_char = "";    # This is a cheat, used to get some context
                                      # for one-character tokens that consist of
                                      # just a quote char. What we do is remember
                                      # the last character of the previous text
                                      # token, to use as context to curl single-
                                      # character quote tokens correctly.

    foreach my $cur_token (@$tokens) {
        if ( $cur_token->[0] eq "tag" ) {

            # Don't mess with quotes inside tags.
            $result .= $cur_token->[1];
            if ( $cur_token->[1] =~ m/$tags_to_skip/ ) {
                $in_pre = defined $1 && $1 eq '/' ? 0 : 1;
            }
        }
        else {
            my $t = $cur_token->[1];
            my $last_char = substr( $t, -1 );    # Remember last char of this token before processing.
            if ( !$in_pre ) {
                $t = ProcessEscapes($t);

                if ($convert_quot) {
                    $t =~ s/&quot;/"/g;
                }

                if ($do_dashes) {
                    $t = EducateDashes($t)                  if ( $do_dashes == 1 );
                    $t = EducateDashesOldSchool($t)         if ( $do_dashes == 2 );
                    $t = EducateDashesOldSchoolInverted($t) if ( $do_dashes == 3 );
                }

                $t = EducateEllipses($t) if $do_ellipses;

                # Notes: backticks need to be processed before quotes.
                if ($do_backticks) {
                    $t = EducateBackticks($t);
                    $t = EducateSingleBackticks($t) if ( $do_backticks == 2 );
                }

                if ($do_quotes) {
                    if ( $t eq q/'/ ) {

                        # Special case: single-character ' token
                        if ( $prev_token_last_char =~ m/\S/ ) {
                            $t = "&#8217;";
                        }
                        else {
                            $t = "&#8216;";
                        }
                    }
                    elsif ( $t eq q/"/ ) {

                        # Special case: single-character " token
                        if ( $prev_token_last_char =~ m/\S/ ) {
                            $t = "&#8221;";
                        }
                        else {
                            $t = "&#8220;";
                        }
                    }
                    else {

                        # Normal case:
                        $t = EducateQuotes($t);
                    }
                }

                $t = StupefyEntities($t) if $do_stupefy;
            }
            $prev_token_last_char = $last_char;
            $result .= $t;
        }
    }

    return $result;
}

=head2 SmartQuotes

Quotes to entities.

=cut

sub SmartQuotes {

    # Paramaters:
    my $text = shift;    # text to be parsed
    my $attr = shift;    # value of the smart_quotes="" attribute

    my $do_backticks;    # should we educate ``backticks'' -style quotes?

    if ( $attr == 0 ) {

        # do nothing;
        return $text;
    }
    elsif ( $attr == 2 ) {

        # smarten ``backticks'' -style quotes
        $do_backticks = 1;
    }
    else {
        $do_backticks = 0;
    }

    # Special case to handle quotes at the very end of $text when preceded by
    # an HTML tag. Add a space to give the quote education algorithm a bit of
    # context, so that it can guess correctly that it's a closing quote:
    my $add_extra_space = 0;
    if ( $text =~ m/>['"]\z/ ) {
        $add_extra_space = 1;    # Remember, so we can trim the extra space later.
        $text .= " ";
    }

    my $tokens ||= _tokenize($text);
    my $result = '';
    my $in_pre = 0;              # Keep track of when we're inside <pre> or <code> tags

    my $prev_token_last_char = "";    # This is a cheat, used to get some context
                                      # for one-character tokens that consist of
                                      # just a quote char. What we do is remember
                                      # the last character of the previous text
                                      # token, to use as context to curl single-
                                      # character quote tokens correctly.

    foreach my $cur_token (@$tokens) {
        if ( $cur_token->[0] eq "tag" ) {

            # Don't mess with quotes inside tags
            $result .= $cur_token->[1];
            if ( $cur_token->[1] =~ m/$tags_to_skip/ ) {
                $in_pre = defined $1 && $1 eq '/' ? 0 : 1;
            }
        }
        else {
            my $t = $cur_token->[1];
            my $last_char = substr( $t, -1 );    # Remember last char of this token before processing.
            if ( !$in_pre ) {
                $t = ProcessEscapes($t);
                if ($do_backticks) {
                    $t = EducateBackticks($t);
                }

                if ( $t eq q/'/ ) {

                    # Special case: single-character ' token
                    if ( $prev_token_last_char =~ m/\S/ ) {
                        $t = "&#8217;";
                    }
                    else {
                        $t = "&#8216;";
                    }
                }
                elsif ( $t eq q/"/ ) {

                    # Special case: single-character " token
                    if ( $prev_token_last_char =~ m/\S/ ) {
                        $t = "&#8221;";
                    }
                    else {
                        $t = "&#8220;";
                    }
                }
                else {

                    # Normal case:
                    $t = EducateQuotes($t);
                }

            }
            $prev_token_last_char = $last_char;
            $result .= $t;
        }
    }

    if ($add_extra_space) {
        $result =~ s/ \z//;    # Trim trailing space if we added one earlier.
    }
    return $result;
}

=head2 SmartDashes

Call the individual dash conversion to entities functions.

=cut

sub SmartDashes {

    # Paramaters:
    my $text = shift;          # text to be parsed
    my $attr = shift;          # value of the smart_dashes="" attribute

    # reference to the subroutine to use for dash education, default to EducateDashes:
    my $dash_sub_ref = \&EducateDashes;

    if ( $attr == 0 ) {

        # do nothing;
        return $text;
    }
    elsif ( $attr == 2 ) {

        # use old smart dash shortcuts, "--" for en, "---" for em
        $dash_sub_ref = \&EducateDashesOldSchool;
    }
    elsif ( $attr == 3 ) {

        # inverse of 2, "--" for em, "---" for en
        $dash_sub_ref = \&EducateDashesOldSchoolInverted;
    }

    my $tokens;
    $tokens ||= _tokenize($text);

    my $result = '';
    my $in_pre = 0;    # Keep track of when we're inside <pre> or <code> tags
    foreach my $cur_token (@$tokens) {
        if ( $cur_token->[0] eq "tag" ) {

            # Don't mess with quotes inside tags
            $result .= $cur_token->[1];
            if ( $cur_token->[1] =~ m/$tags_to_skip/ ) {
                $in_pre = defined $1 && $1 eq '/' ? 0 : 1;
            }
        }
        else {
            my $t = $cur_token->[1];
            if ( !$in_pre ) {
                $t = ProcessEscapes($t);
                $t = $dash_sub_ref->($t);
            }
            $result .= $t;
        }
    }
    return $result;
}

=head2 SmartEllipses

Call the individual ellipse conversion to entities functions.

=cut

sub SmartEllipses {

    # Paramaters:
    my $text = shift;    # text to be parsed
    my $attr = shift;    # value of the smart_ellipses="" attribute

    if ( $attr == 0 ) {

        # do nothing;
        return $text;
    }

    my $tokens;
    $tokens ||= _tokenize($text);

    my $result = '';
    my $in_pre = 0;      # Keep track of when we're inside <pre> or <code> tags
    foreach my $cur_token (@$tokens) {
        if ( $cur_token->[0] eq "tag" ) {

            # Don't mess with quotes inside tags
            $result .= $cur_token->[1];
            if ( $cur_token->[1] =~ m/$tags_to_skip/ ) {
                $in_pre = defined $1 && $1 eq '/' ? 0 : 1;
            }
        }
        else {
            my $t = $cur_token->[1];
            if ( !$in_pre ) {
                $t = ProcessEscapes($t);
                $t = EducateEllipses($t);
            }
            $result .= $t;
        }
    }
    return $result;
}

=head2 EducateQuotes

   Parameter:  String.

   Returns:    The string, with "educated" curly quote characters.

   Example input:  "Isn't this fun?"
   Example output: &#8220;Isn&#8217;t this fun?&#8221;

=cut

sub EducateQuotes {
    local $_ = shift;

    # Tell perl not to gripe when we use $1 in substitutions,
    # even when it's undefined. Use $^W instead of "no warnings"
    # for compatibility with Perl 5.005:
    local $^W = 0;

    # Make our own "punctuation" character class, because the POSIX-style
    # [:PUNCT:] is only available in Perl 5.6 or later:
    my $punct_class = qr/[!"#\$\%'()*+,-.\/:;<=>?\@\[\\\]\^_`{|}~]/;

    # Special case if the very first character is a quote
    # followed by punctuation at a non-word-break. Close the quotes by brute force:
    s/^'(?=$punct_class\B)/&#8217;/;
    s/^"(?=$punct_class\B)/&#8221;/;

    # Special case for double sets of quotes, e.g.:
    #   <p>He said, "'Quoted' words in a larger quote."</p>
    s/"'(?=\w)/&#8220;&#8216;/g;
    s/'"(?=\w)/&#8216;&#8220;/g;

    my $close_class = qr![^\ \t\r\n\[\{\(]!;

    # Single closing quotes:
    s {
        ($close_class)?
        '
        (?(1)|          # If $1 captured, then do nothing;
          (?=\s | s\b)  # otherwise, positive lookahead for a whitespace
        )               # char or an 's' at a word ending position. This
                        # is a special case to handle something like:
                        # "<i>Custer</i>'s Last Stand."
    } {$1&#8217;}xgi;

    # Single opening quotes:
    s/'/&#8216;/g;

    # Double closing quotes:
    s {
        ($close_class)?
        "
        (?(1)|(?=\s))   # If $1 captured, then do nothing;
                           # if not, then make sure the next char is whitespace.
    } {$1&#8221;}xg;

    # Double opening quotes:
    s/"/&#8220;/g;

    return $_;
}

=head2 EducateBackticks

Replace double (back)ticks w/ characters.

=cut

sub EducateBackticks {

    #
    #   Parameter:  String.
    #   Returns:    The string, with ``backticks'' -style double quotes
    #               translated into HTML curly quote entities.
    #
    #   Example input:  ``Isn't this fun?''
    #   Example output: &#8220;Isn't this fun?&#8221;
    #

    local $_ = shift;
    s/``/&#8220;/g;
    s/''/&#8221;/g;
    return $_;
}

=head2 EducateSingleBackticks

Replace single (back)ticks w/ characters.

=cut

sub EducateSingleBackticks {

    #
    #   Parameter:  String.
    #   Returns:    The string, with `backticks' -style single quotes
    #               translated into HTML curly quote entities.
    #
    #   Example input:  `Isn't this fun?'
    #   Example output: &#8216;Isn&#8217;t this fun?&#8217;
    #

    local $_ = shift;
    s/`/&#8216;/g;
    s/'/&#8217;/g;
    return $_;
}

=head2 EducateDashes

Dashes to character

   Parameter:  String.

   Returns:    The string, with each instance of "--" translated to
               an em-dash character.

=cut

sub EducateDashes {

    local $_ = shift;
    s/--/&#8212;/g;
    return $_;
}

=head2 EducateDashesOldSchool

Dashes to entities.


   Parameter:  String.

   Returns:    The string, with each instance of "--" translated to
               an en-dash character, and each "---" translated to
               an em-dash character.


=cut

sub EducateDashesOldSchool {

    local $_ = shift;
    s/---/&#8212;/g;    # em
    s/--/&#8211;/g;     # en
    return $_;
}

=head2 EducateDashesOldSchoolInverted


   Parameter:  String.

   Returns:    The string, with each instance of "--" translated to
               an em-dash character, and each "---" translated to
               an en-dash character. Two reasons why: First, unlike the
               en- and em-dash syntax supported by
               EducateDashesOldSchool(), it's compatible with existing
               entries written before SmartyPants 1.1, back when "--" was
               only used for em-dashes.  Second, em-dashes are more
               common than en-dashes, and so it sort of makes sense that
               the shortcut should be shorter to type. (Thanks to Aaron
               Swartz for the idea.)


=cut

sub EducateDashesOldSchoolInverted {

    local $_ = shift;
    s/---/&#8211;/g;    # en
    s/--/&#8212;/g;     # em
    return $_;
}

=head2 EducateEllipses

   Parameter:  String.
   Returns:    The string, with each instance of "..." translated to
               an ellipsis character.

   Example input:  Huh...?
   Example output: Huh&#8230;?

=cut

sub EducateEllipses {

    local $_ = shift;
    s/\.\.\./&#8230;/g;
    return $_;
}

=head2 ProcessEscapes

   Parameter:  String.
   Returns:    The string, with after processing the following backslash
               escape sequences. This is useful if you want to force a "dumb"
               quote or other character to appear.

               Escape  Value
               ------  -----
               \\      &#92;
               \"      &#34;
               \'      &#39;
               \.      &#46;
               \-      &#45;
               \`      &#96;

=cut

sub ProcessEscapes {

    local $_ = shift;

    s! \\\\ !&#92;!gx;
    s! \\"  !&#34;!gx;
    s! \\'  !&#39;!gx;
    s! \\\. !&#46;!gx;
    s! \\-  !&#45;!gx;
    s! \\`  !&#96;!gx;

    return $_;
}

sub _tokenize {

    #
    #   Parameter:  String containing HTML markup.
    #   Returns:    Reference to an array of the tokens comprising the input
    #               string. Each token is either a tag (possibly with nested,
    #               tags contained therein, such as <a href="<MTFoo>">, or a
    #               run of text between tags. Each element of the array is a
    #               two-element array; the first is either 'tag' or 'text';
    #               the second is the actual value.
    #
    #
    #   Based on the _tokenize() subroutine from Brad Choate's MTRegex plugin.
    #       <http://www.bradchoate.com/past/mtregex.php>
    #

    my $str = shift;

    my $pos = 0;
    my $len = length $str;
    my @tokens;

    # pattern to match balanced nested <> pairs, up to two levels deep:
    my $nested_angles = qr/<(?:[^<>]|<[^<>]*>)*>/;

    while ( $str =~ m/($nested_angles)/gs ) {
        my $whole_tag = $1;
        my $sec_start = pos $str;
        my $tag_start = $sec_start - length $whole_tag;
        if ( $pos < $tag_start ) {
            push @tokens, [ 'text', substr( $str, $pos, $tag_start - $pos ) ];
        }
        push @tokens, [ 'tag', $whole_tag ];
        $pos = pos $str;
    }
    push @tokens, [ 'text', substr( $str, $pos, $len - $pos ) ] if $pos < $len;
    \@tokens;
}

1;

=pod

=head1 NAME

Plerd::SmartyPants

=head1 DESCRIPTION

This is a fork of Text::SmartyPants version 1.3, originally by John Gruber. (See
L<"Copyright and License">, below.) It has been simplified and customized for
use by the Plerd static blog generator by Jason McIntosh.

Unlike Text::SmartyPants, it's not intended for use in any other context.

The biggest difference between Plerd::SmartyPants and Text::SmartyPants is that
the former doesn't convert anything into HTML entities; instead it converts
its ASCII input directly into UTF-8 characters.

=head1 Copyright and License

    Copyright (c) 2003 John Gruber
    (http://daringfireball.net/)
    All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

*   Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

*   Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

*   Neither the name "SmartyPants" nor the names of its contributors may
    be used to endorse or promote products derived from this software
    without specific prior written permission.

This software is provided by the copyright holders and contributors "as is"
and any express or implied warranties, including, but not limited to, the
implied warranties of merchantability and fitness for a particular purpose
are disclaimed. In no event shall the copyright owner or contributors be
liable for any direct, indirect, incidental, special, exemplary, or
consequential damages (including, but not limited to, procurement of
substitute goods or services; loss of use, data, or profits; or business
interruption) however caused and on any theory of liability, whether in
contract, strict liability, or tort (including negligence or otherwise)
arising in any way out of the use of this software, even if advised of the
possibility of such damage.

=cut
