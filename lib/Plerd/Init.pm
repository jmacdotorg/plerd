package Plerd::Init;

use utf8;
use warnings;
use strict;
use Path::Class::Dir;
use LWP;
use Plerd;
use Try::Tiny;

my %file_content;

sub initialize ( $$ ) {
    my ($init_path, $is_using_default) = @_;

    my @messages;

    my $dir = Path::Class::Dir->new( $init_path )->absolute;

    if ( $is_using_default ) {
        push @messages,
            "No directory provided, so using default location ($dir).\n"
    }

    if (-e $dir) {
        unless (-d $dir) {
            return [
                @messages,
                "$dir exists, but it's not a directory!\nExiting."
            ];
        }
        if ( $dir->children ) {
            return [
                @messages,
                "$dir exists, but it's not empty!\nExiting."
            ];
        }
    }
    else {
        unless (mkdir $dir) {
            return [
                @messages,
                "Cannot create $dir: $!"
            ];
        }
    }

    my $success = populate_directory( $dir, \@messages );

    if ( $success ) {
        my $config_file = Path::Class::File->new( $dir, 'plerd.conf' );
        push @messages,
            "I have created and populated a new Plerd working directory at "
            . "$dir. Your next step involves updating the configuration file "
            . "at $config_file.\n"
            . "For full documentation, links to mailing lists, and other stuff, "
            . "please visit http://plerd.jmac.org/. Enjoy!";
    }
    return \@messages;
}

sub populate_directory ( $$ ) {
    my ( $dir, $messages ) = @_;

    my %file_content = file_content( $dir );

    try {
        foreach ( qw( docroot source templates log run db conf ) ) {
            my $subdir = Path::Class::Dir->new( $dir, $_ );
            mkdir $subdir or die "Can't create subdir $subdir: $!";
        }

        foreach ( qw( archive atom jsonfeed post wrapper tags ) ) {
            my $template = Path::Class::File->new(
                $dir, 'templates', "$_.tt",
            );
            $template->spew( iomode=>'>:encoding(utf8)', $file_content{ $_ } );
        }

        my $config = Path::Class::File->new(
            $dir, 'conf', 'plerd.conf',
        );

        $config->spew( iomode=>'>:encoding(utf8)', $file_content{ config } );

    }
    catch {
        push @$messages, $_;
        push @$messages, "I am cowardly declining to clean up $dir. You might "
                         . "need to empty or remove it yourself before trying "
                         . "this command again.";
        push @$messages, "Exiting.";
        return 0;
    };

    return 1;

}

sub file_content ( $ ) {
my ( $dir ) = @_;
%file_content = (
archive => <<EOF,
[% WRAPPER wrapper.tt title = plerd.title _ ': Archives ' %]

<div class="page-header">
<h1>Archive</h1>
</div>

[% current_month = 0 %]
[% FOREACH post IN posts %]
    [% post_month = post.year _ post.month %]
    [% IF !current_month || current_month != post_month %]
        [% IF current_month %]
            </ul>
        [% END %]
        <h2>[% post.month_name %] [% post.year %]</h2>
        <ul>
    [% END %]
    <li><a href="[% post.uri %]">[% post.title %]</a></li>
    [% current_month = post_month %]
[% END %]

[% IF current_month %]
    </ul>
[% END %]

[% END %]
EOF
atom => <<EOF,
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">

  <title><![CDATA[[% plerd.title %]]]></title>
  <link href="[% plerd.base_uri %]/atom.xml" rel="self" />
  <link href="[% plerd.base_uri %]" />
  <updated>[% timestamp %]</updated>
  <id>[% plerd.base_uri %]</id>
  <author>
    <name><![CDATA[[% plerd.author_name %]]]></name>
    <email><![CDATA[[% plerd.author_email %]]]></email>
  </author>
  <generator uri="https://github.com/jmacdotorg/plerd">Plerd</generator>

[% FOR post IN posts %]
  <entry>
    <title type="html"><![CDATA[[% post.title %]]]></title>
    <link href="[% post.uri %]"/>
    <published>[% post.published_timestamp %]</published>
    <updated>[% post.updated_timestamp %]</updated>
    <id>[% post.uri %]</id>
    <content type="html"><![CDATA[[% post.body %]]]></content>
  </entry>
[% END %]

</feed>
EOF
jsonfeed => <<EOF,
{
  "version": "https://jsonfeed.org/version/1",
  "title": "[% plerd.title %]",
  "home_page_url": "[% plerd.base_uri %]",
  "feed_url": "[% plerd.base_uri %]/feed.json",
  "user_comment": "This feed allows you to read the posts from this site in any feed reader that supports the JSON Feed format. To add this feed to your reader, copy the following URL — [% plerd.base_uri %]/feed.json — and add it your reader.",
  "author": {
    "name": "[% plerd.author_name %]"[% IF plerd.author_email %],
    "url": "mailto:[% plerd.author_email %]"[% END %]
  },
  "items": [
[% post_count = 0 %]
[% FOR post IN posts %]
    [% post_count = post_count + 1 %]
    {
      "id": "[% post.uri %]",
      "url": "[% post.uri %]",
      "title": "[% post.title %]",
      "content_html": "[% post.body | json %]",
      "date_published": "[% post.published_timestamp %]",
      "date_modified": "[% post.updated_timestamp %]"
    }[% IF post_count < posts.size %],[% END %]
[% END %]
  ]
}
EOF
post => <<EOF,
[% WRAPPER wrapper.tt %]

[% FOREACH post IN posts %]
<div class="post h-entry">
    <div class="title page-header"><h1><a href="[% post.uri %]"><span class="p-name">[% post.title %]</span><br /><small>[% post.month_name %] [% post.day %], [% post.year %]</small></a></h1></div>

    <data class="dt-published" value="[% post.ymd %] [% post.hms %]"></data>
    <data class="p-author h-card">
        <data class="p-name" value="[% post.plerd.author_name | html %]"></data>
    </data>
    <data class="p-summary" value="[% post.description | html %]"></data>
    <data class="u-url u-uid" value="[% post.uri %]"></data>

    <div class="body e-content">[% post.body %]</div>
</div>
[% END %]

[% IF posts.size == 1 %]

    <div>
        <hr />
        [% IF post.newer_post %]
            <p>Next post: <a href="[% post.newer_post.uri %]">[% post.newer_post.title %]</a></p>
        [% END %]
        [% IF post.older_post %]
            <p>Previous post: <a href="[% post.older_post.uri %]">[% post.older_post.title %]</a></p>
        [% END %]
    </div>

    [% IF post.ordered_webmentions && post.ordered_webmentions.size > 0 %]
    <hr />
    <h3>Responses from around the web...</h3>
        <div class="row">
            <div class="col-xs-6">
                [% INCLUDE likes %]
            </div>
            <div class="col-xs-6">
                [% INCLUDE reposts %]
            </div>
        </div>
        <div class="row">
            <div class="col-xs-12">
                [% INCLUDE responses %]
            </div>
        </div>
    [% END %]


[% END %]


[% END %]

[% BLOCK likes %]
<h4>Likes</h4>
[% INCLUDE facepile type="like" %]
[% END %]

[% BLOCK reposts %]
<h4>Reposts</h4>
[% INCLUDE facepile type="repost" %]
[% END %]

[% BLOCK facepile %]
    <p>
    [% count = 0 %]
    [% FOREACH webmention IN post.ordered_webmentions %]
        [% IF webmention.type == type %]
            <a href="[% webmention.author.url %]"><img class="facepile" src="[% webmention.author.photo %]" alt="[% webmention.author.name %] avatar" style="width:32px"></a>
            [% count = count + 1 %]
        [% END %]
    [% END %]
    [% UNLESS count %]
        (None yet!)
    [% END %]
    </p>
[% END %]

[% BLOCK responses %]
    <h4>Replies</h4>
    [% INCLUDE mention_list types=['reply', 'quotation'] %]
    <h4>Other webpages that mention this post</h4>
    [% INCLUDE mention_list types=['mention'] %]

[% END %]

[% BLOCK mention_list %]
    [% count = 0 %]
    [% FOREACH webmention IN post.ordered_webmentions %]
        [% match = 0 %]
        [% FOREACH type IN types %]
            [% IF webmention.type == type %]
                [% match = 1 %]
            [% END %]
        [% END %]
        [% IF match %]
        [% count = count + 1 %]
        <div class="media">
            <div class="media-left">
                [% IF webmention.author %]
                <a rel="nofollow" href="[% webmention.author.url %]">
                <img class="media-object" src="[% webmention.author.photo || 'http://fogknife.com/images/comment.png' %]" alt="[% IF webmention.author.photo %][% webmention.author.name %] avatar[% ELSE %]A generic word balloon[% END %]" style="max-width:32px; max-height:32px;">
                </a>
                [% ELSE %]
                <a rel="nofollow" href="[% webmention.original_source %]">
                <img class="media-object" src="http://fogknife.com/images/comment.png" alt="A generic word balloon" style="max-width:32px; max-height:32px;">
                </a>
                [% END %]
            </div>
            <div class="media-body">
                [% IF webmention.author %]
                <h4 class="media-heading"><a href="[% webmention.author.url %]">[% webmention.author.name %]</a></h4>
                [% ELSE %]
                <h4 class="media-heading"><a href="[% webmention.original_source %]">[% webmention.original_source.host %]</a></h4>
                [% END %]
                    [% IF type == 'mention' %]
                    <p><strong>[% webmention.source_mf2_document.get_first('entry').get_property('name') %]</strong></p>
                    [% END %]
                    [% webmention.content %] <a rel="nofollow" href="[% webmention.original_source %]"><span class="glyphicon glyphicon-share" style="text-decoration:none; color:black;"></a>
            </div>
        </div>
        [% END %]
    [% END %]
    [% UNLESS count %]
        (None yet!)
    [% END %]
[% END %]


<style>
/* img.media-object { max-width: 64px } */
</style>
EOF
wrapper => <<EOF,
<!DOCTYPE html>
<html>
<head>
    <title>[% title %]</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://netdna.bootstrapcdn.com/bootstrap/3.0.3/css/bootstrap.min.css" rel="stylesheet">
    <link href="atom.xml" rel="alternate" title="Atom feed" type="application/atom+xml">
    <link href="feed.json" rel="alternate" title="JSON feed" type="application/json">

<!--
    Uncomment the following <link> tag if you set up a Webmention receiver
    using plerdwatcher. Update the port number as needed.
-->
<!--
    [% webmention_uri = plerd.base_uri.clone %]
    [% old_port = webmention_uri.port( 4000 ) %]
    <link rel="webmention" href="[% webmention_uri %]" />
-->

    <meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
    [% IF context_post %]
        [% context_post.social_meta_tags %]
    [% END %]
    <style>
        .page-header h1 :link, .page-header h1 :visited {
            color: black;
        }
        .sidebar h1 {
            font-size: 1.5em;
        }
        img.author-link {
            width: 20px;
        }
        .sidebar section {
            margin-top: 2em;
        }
        img {
            width: 100%;
        }
    </style>
</head>
<body>
    <div class="navbar navbar-default" role="navigation">
        <div class="container">
            <div class="navbar-header">
                <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
                    <span class="sr-only">Toggle navigation</span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                    <span class="icon-bar"></span>
                </button>
                <a class="navbar-brand" href="recent.html">[% plerd.title %]</a>
            </div>
            <div class="navbar-collapse collapse">
                <ul class="nav navbar-nav">
                    <li><a href="archive.html">Archive</a></li>
                    <li><a href="atom.xml">RSS</a></li>
                </ul>
            </div><!--/.navbar-collapse -->
        </div>
    </div>

    <div class="container">
    <div class="row">
        <div class="col-sm-9">
            [% content %]
        </div>
        <div class="col-sm-3 sidebar">
            <section>
                <h1>Hello</h1>
                <p>
                    This is a blog by <a href="mailto:[% plerd.author_email %]">[% plerd.author_name %]</a>.
                </p>
            </section>
            <section>
                <h1>Search</h1>
                <form action="https://duckduckgo.com" method="get">
                <input name="q" type="text" placeholder="Search this blog" />
                <input name="sites" type="hidden" value="[% plerd.base_uri %]" />
                <input type="submit" value="Go" />
                </form>
            </section>
            <section>
                <h1>Recent Posts</h1>
                <ul>
                [% FOR post IN plerd.recent_posts %]
                    <li><a href="[% post.uri %]">[% post.title %]</a></li>
                [% END %]
                </ul>
            </section>
        </div>
    </div>
     <footer style="font-size:small; font-style:italic" class="container">
        <hr />
        <p>Powered by <a href="http://jmac.org/plerd">Plerd</a>.</p>
        </footer>
    </div>

    <script type="text/javascript" src="https://code.jquery.com/jquery.js"></script>
    <script type="text/javascript" src="https://netdna.bootstrapcdn.com/bootstrap/3.0.3/js/bootstrap.min.js"></script>
    </body>
</html>
EOF
config => <<"EOF",
# This is a configuration file for a single Plerd-based blog!
#
# Update the values below to best suit your blogging needs. After that,
# you can then either copy (or symlink) this file to .plerd in your home
# directory for use as a system-wide default, or you can specify this
# file when running the `plerd` or `plerdwatcher` programs through their
# --config command-line option. (See these programs' respective man
# pages for more details.)

#####################
# Required setup
#####################
# Values for these fields are all required for Plerd to work properly.

# base_uri: The URI base that this blog will use when generating various
#           self-pointing links. Generally, this should be the same as your
#           blog's "front page" URL.
base_uri:     http://blog.example.com/

# path: The path on your filesystem where Plerd will find this blog's
# source, docroot, and other important sub-directories. (If you don't
# want to keep all these under a single master directory, see
# "Split-location setup", below.)
path:         $dir

# title: This blog's title.
title:        My Cool Blog

# author_name: The name of this blog's author.
author_name:  Sam Handwich

# author_email: The email address of this blog's author.
author_email: s.handwich\@example.com

######################
# Social-media setup
######################
# Fill in these values in order to activate Open Graph and Twitter Card support
# for your Plerd-based blog.

# facebook_id: Your blogs's Facebook App ID number.
#              If you define this, then Plerd will try to generate Open Graph
#              metatags on each post's webpage.
#              (Yes, you need to register your blog as an "app" on Facebook for
#              this. Don't look at me, I don't decide how that stuff works.)
facebook_id: 123456789876543212345678987654321

# twitter_id: The Twitter username to associate with this blog.
#             If you define this, then Plerd will try to generate Twitter Card
#             metatags on each post's webpage.
#             (Don't include the leading '\@', please.)
twitter_id: MyBlogsTwitterUsername

# image: Your blog's "logo", used as a fallback image for posts that do not
#        define an image themselves.
#        Optional, but if you don't define this, then posts without their
#        own image attributes won't get any social-media metatags.
image: http://blog.example.com/images/blog_logo.png

# image_alt: A text description of your image, equivalent to the "alt" attribute
#            in HTML <img> tags, and useful for visually impaired visitors to
#            your blog.
#            Optional, but if you define an image, you should define this too.
image_alt: "My Cool Blog's logo -- a photograph of Fido, the author's gray tabby cat."

######################
# Split-location setup
######################
# If you don't want to keep all of Plerd's required directories under a single
# master directory (configured withe the "path" directive, as seen above), then
# you can define the directories with these separate directives instead:
#
# source_path:      /home/me/Dropbox/plerd/source
# publication_path: /var/www/html/blog/
# template_path:    /yet/another/path/templates
# database_path:    /opt/plerd/db
# run_path:         /tmp/plerd/run
# log_path:         /var/log/plerd/
EOF
tags => <<EOF,
[% WRAPPER wrapper.tt title = 'Tags' %]

[%   IF is_tags_index_page %]
<section>
    <h1>All Tags</h1>

    <ul>
    [% FOREACH tag = tags.keys.sort %]
        <li><a href="[% plerd.tag_uri(tag) %]">[% tag %]</a> ([% tags.\$tag.size %])</li>
    [% END %]
    </ul>
</section>
[%   ELSE %]

    [% FOREACH tag = tags.keys %]
      <h1>[% tag %]</h1>
      <ul>
        [% FOREACH post = tags.\$tag %]
            <li><a href="[% post.uri %]">[% post.title %]</a></li>
        [% END %]
      </ul>
    [% END %]

[%   END %]

[% END %]

EOF
);
return %file_content;
}

1;

=head1 NAME

Plerd::Init

=head1 DESCRIPTION

This module just defines a bunch of utility classes used by plerdall's
"init" verb. It offers no public API.

=head1 SEE ALSO

Plerd

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>
