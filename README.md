[![Test](https://github.com/jmacdotorg/plerd/actions/workflows/test.yml/badge.svg)](https://github.com/jmacdotorg/plerd/actions/workflows/test.yml)

# Plerd

Plerd strives to be an ultralight blogging platform for Markdown fans.

It allows you to compose and maintain blog posts as easily as adding and modifying Markdown files in a single folder. Plerd creates an entirely static website based on the content of this one folder, automatically updating the site whenever this content changes.

Plerd also supports IndieWeb technologies, such as [microformats](https://indieweb.org/microformats) and [Webmention](https://indieweb.org/Webmention).

## Purpose

Plerd allows you to publish new posts to your blog by adding Markdown files to a designated blog-source directory. Typically, this folder lives on your web server, and you sync its contents to your laptop or other local machine using Dropbox, rclone, or a similar technology. You can update posts by updating these source files, or unpublish posts by deleting or moving files out of the source folder.

The generated website comprises a single directory containing only static files. These include one "permalink" HTML page for every post, a recent-posts front page, a single archive page (in the manner of [Daring Fireball](http://daringfireball.net/archive)), a tags page, and syndication documents in Atom and [JSON Feed](http://jsonfeed.org) formats. All these are constructed from fully customizable templates.

That's it! That's all Plerd does.

### Plerd versus other static site generators

Plerd is much narrower in scope than ubiquitous and feature-rich static site generators such as Hugo and Jekyll. Plerd is great at producing blogs, podcasts, or other websites that each present a single, time-ordered array of posts with syndication feeds, using a workflow that I try to keep as simple and fast as possible.

Unlike more popular platforms, creating/updating/deleting a post involves creating/updating/deleting a source file using any text editor you like, and then taking no further actions. Plerd has no concept of staging, previewing, or committing changes, and no requirement to manually rebuild a site after a content change. A daemon watches a source folder, and when it sees changes it makes corresponding changes in an output folder that contains a browser-ready website.

### A brief apologia for Plerd

More to the point, Plerd is the blogging platform that I, Jason McIntosh, want to use. It is written in the unpopular programming language that I'm most fluent with, around features specifically tailored to my own writing preferences. This includes my distaste for needing to treat my blogs like version-controlled software repositories. I want my blogs to be public notebooks: readable, but a bit messy, honest, dog-eared. Personal. It grows new features according to my own ever-developing tastes.

I share Plerd as a public, open-source project in order to keep this software as high-quality as I can, for my own use. If Plerd works well for others too, then I consider it a welcome accident—just as I welcome suggestions or proposals for improvements that align with my own taste.

[This 20-minute presentation about my reasons for creating Plerd](http://fogknife.com/2015-06-09-my-yapcna-2015-talk-about-blogging.html) remains as true today as it was when I delivered it to a Perl conference in 2015.

## Project status

Plerd is released and stable. I have been using it continuously since 2014, across a variety of self-hosted blogs and podcast sites.

It still has plenty of room for improvement, and I welcome community feedback and patch proposals. It will continue to do what it does now, in more or less the same fashion, for the foreseeable future.

I do my best to avoid breaking functionality when I do release updates to Plerd, and to clearly announce when something does need to break. To stay informed about Plerd development, follow [the Plerd blog](https://plerd.jmac.org), where I post news about significant updates, including breaking changes.

## Setup

### Installation

**First, make sure you have the `cpanm` program on your machine.** It is likely
available as "cpanminus" in your favorite package manager. (Or install it from
source, through the instructions at [http://cpanmin.us](http://cpanmin.us).)

Then, to install the latest release of Plerd, run this command:

    cpanm Plerd

If you run into issues due to dependencies failing their tests, you can try one of these instead:

    cpanm --notest Plerd

    # Or, if the above doesn't work:
    cpanm --force Plerd

Alternately, you can run these commands under \`sudo\` to install Plerd at the system level.

If everything installed as it should, then you should have the `plerdall` and `plerdwatcher` programs in your command path.

**To install Plerd from source** instead, set the current working directory to the same directory containing this README file, make sure you have `cpanm` as described above, and then do this:

    cpanm --installdeps .
    perl Makefile.PL
    make
    make install
    

### Configuration

1. Run `plerdall --init` to create a new directory called `plerd/` in your current working directory, populated with all the special files and directories that Plerd requires. This includes a sample config file in `plerd/conf/plerd.conf`.

    If you'd like the directory named something else or located somewhere else, you can provide it as an argument, e.g. `plerdall --init=/some/other/location`. See the `plerdall` man page for full details.

    Here's the purpose of the subdirectories that `plerdall --init` creates:

    - `source`: The directory holding your blog's Markdown-based source files.
    - `templates`: Your blog's template directory. `plerdall --init` will place a full complement of sample templates in this directory for you.
    - `docroot`: Your blog's actual docroot, ready for serving up by the webserver software of your choice.
    - `conf`: Holds your blog's configuration files. `plerdall --init` will place an example `plerd.conf` file in this directory for you.
    - `db`: The directory containing metadata about your blog's posts.
    - `run`: A directory for PID files and such.
    - `log`: The `plerdwatcher` program writes logs here.

    You can freely add other files or directories in this directory if you wish (a `drafts` folder, perhaps?). Plerd happily ignores them.

2. Edit the `conf/plerd.conf` file to best suit your needs. The file itself is extensively commented and self-documenting.

    You can optionally move or copy the configuration file to `.plerd` in your home directory. If you do, that new copy of the file becomes the default configuration file that Plerd's command-line programs will refer to.

3. As noted above, the `templates` directory that you created in the first step of this process contains sample templates that you can customize as much as you'd like. They are rendered using [Template Toolkit](http://www.template-toolkit.org). You can't change these template files' names, but you can add new sub-template files that the main templates will invoke via [the \[% INCLUDE %\] directive](http://www.template-toolkit.org/docs/manual/Directives.html#section_INCLUDE), and so on.
4. Configure the webserver of your choice such that it treats the `docroot` subdirectory (which you created as part of the first step) as your new blog's own docroot.

    When running in its basic mode, Plerd does not provide a webserver; it simply generates static HTML & XML files, ready for some other process to serve up.

## Usage

### Running Plerd

Plerd includes two command-line programs:

- **plerdall** creates a new website in Plerd's docroot directory, based on the contents of its source and templates directories. (It also provides a few other "one-off" utility functions, including the `--init` feature referred to above.)

    Run this program (with no arguments) to initially populate your blog's docroot, and at any other time you wish to manually regenerate your blog's served files.

- **plerdwatcher** runs a daemon that monitors the source directory for changes, republishing files as necessary.

    **_This is where the magic happens._** While _plerdwatcher_ runs, any changes you make to your blog's source directory will instantly update your blog's published static files as appropriate. Pair this with a syncing technology such as Dropbox (see ["Write locally, publish remotely"](#write-locally-publish-remotely), below), and updates to source files on your laptop or other preferred writing machine instantly propagate to your published blog.

    Launch plerdwatcher through this command:

        plerdwatcher start

    It also accepts the verbs `stop`, `restart`, and `status`, as well as [all the command-line options listed in the App::Daemon documentation](https://metacpan.org/pod/App::Daemon#Command-Line-Options).

### Composing posts

To start writing a new blog post, create a new Markdown file somewhere _outside of your blog's source directory_. (Recall that any change to the source directory instantly republishes the blog, something you won't want to do with a half-written entry on top.) You can name this file whatever you like, so long as the filename ends in either `.markdown` or `.md`.

You must also give your post a title, sometime before you're ready to publish it. To define the title, have the first line of your entry say `title: [whatever]`, followed by two newlines, followed in turn by the body of your post.

For example, a valid, ready-to-publish source file could be called `today.markdown`, and it could contain this, in full:

    title: My day today
    
    I had a pretty good day today. 
    
    I hung out at [the coffee shop](http://empireteaandcoffee.com). Then I went home.
    
    Well, that's all for now. Bye bye.

### Publishing posts

To publish a post, move it to Plerd's source directory. (Take care not to overwrite an older post's source file that may have the same name.)

Plerd will, once it notices the new file, give the file a timestamp recording the date and time of its publication. This timestamp will appear in its own line, after the title line.

Normally, Plerd will set the publication time to the moment that you added the file to the source directory. Plerd recognizes two exceptions to this rule:

- If you manually give your post a `time:` timestamp, and it's in W3C date-time format, then Plerd will leave that timestamp alone.
- If you leave the timestamp out, _and_ include in your post's filename a date of yesterday or earlier (e.g. `1994-06-10-i-like-ace-of-base.md`), then Plerd will set the post's timestamp to midnight (in the local time zone) of that date. This allows you to batch-backdate many posts at once -- useful, perhaps, for populating a new blog with existing writing.

(Note that Plerd assumes you use a text editor smart enough to see that the source file has both moved and had additional lines added to it from an external process, and to react to this in a graceful fashion.)

Once it has prepared the source file, Plerd updates the blog. It creates an HTML file for the new entry, and adds a link to it from the `archive.html` page. If the post's date places it among the blog's more recent posts, then the post also appears in the following places:

- The blog's front page
- Every page's recent-posts sidebar
- The Atom and JSON Feed documents

### Updating or deleting posts

To update a blog post, edit its source Markdown file, right in the source directory. If plerdwatcher is running, then any changes you make will immediately update your published blog.

To unpublish a blog post, move it out of the synced source directory, or just delete it.

## Write locally, publish remotely

Plerd was designed from the outset for compatibility with automated syncing technologies, such as Dropbox or rclone. Compose and edit blog posts via Markdown in your favorite text editor while sitting by the fire with your laptop in the back of your favorite coffee shop, publishing updates to your blog by hitting _File → Save_ in your text editor, and not directly interacting with your webserver (or, indeed, with the Plerd software itself) in any way.

Setting up syncing varies depending upon the syncing technology that you choose. For example, to have Plerd work with Dropbox, follow these steps:

1. Install Dropbox on both your local machine and your webserver machine.
2. Place your blog's working directory (the one containing the source, docroot, and template subdirectories) somewhere in your synced Dropbox folder.
3. Update your server's Plerd configuration to use this Dropbox-based location as its working directory.

As long as Dropbox remains running on both your laptop and your remote server, you can create, update, and delete blog posts by updating files on your laptop, without any need for followup action.

## Advanced use

### Customizing templates

For a brief guide to the template files and how to customize them for your blog, please [see the Plerd wiki on GitHub](https://github.com/jmacdotorg/plerd/wiki/Plerd-template-guide).

### Tags

If you define a list of comma-separated tags under a post attribute named `tags`, then Plerd will add the post to those linked from a file named `tags/[tag].html`, relative to the blog's docroot. It will also link to that page from `tags/index.html`.

For example, this attribute would assign three tags to its post:

    tags: Media, Books I like, 📚

The default Plerd templates will display links to tag-pages where appropriate. Tag pages get their shape from the template named `tags.tt`.

_Mind your capitalization with tags!_ If faced with inconsistent capitalization within a single tag, e.g. one post claims "boston" for a tag and other one claims "Boston", then Plerd will prefer the first tag containing capital letters to one that contains none, and it will retroactively apply it across all relevant posts.

### User-defined attributes

You can add any attributes you'd like to your posts, and then refer to them from your templates via a hash named `attributes` attached to every post object. For example, if a post's metadata looks like this:

    title: Example of user-defined attributes
    byline: Sam Handwich

Then you can refer to `post.attributes.byline` to fetch that value from within the `post.tt` template file, even though "byline" is not an attribute that Plerd otherwise recognizes. (If a template refers to an attribute key that a post's source file does not define, it will simply return a blank value.)

### Social-media metatags

By defining some extra attributes in your blog's configuration file, you
can direct Plerd to add [Open Graph](http://ogp.me) metadata tags to each of your posts. This allows services like Discord and Slack to present attractive little summaries of your blogposts when displaying links to them.

These blog configuration options (all optional) are:

- **image**: If present, Plerd will use this URL as the location of a default image to use in the metadata for any post that doesn't define its own _image_ attribute.

    If _not_ present, Plerd does _not_ generate any social-media metadata for any post lacking an _image_ attribute.

- **image\_alt**: A textual description of the image referenced by the `image` attribute. (Equivalent in usage to the "alt" attribute in an HTML `<img>` tag.) Plerd just leaves this blank if you don't define it yourself.

Once you've configured your blog as described above, you can add these attributes to any post:

- **description**: A very brief summary of this post.

    If not defined, then Plerd will try to use the first paragraph of your post's text (after stripping out any markup) as the post's description.

- **image**: The URL of an image to associate with this post within social-media links. (This could refer to an image that also appears in your post by way of an HTML `<img>` tag, but it doesn't have to.)

    If not defined, then Plerd will instead use the blog's _image_ configuration directive. If _that_ is also undefined, then Plerd will not generate any social-media metadata for this post.

- **image\_alt**: A textual description of the image referenced by the `image` attribute. (Equivalent in usage to the "alt" attribute in an HTML `<img>` tag.) Plerd will just leave this blank, if you don't define it yourself.

### MultiMarkdown

Plerd supports [MultiMarkdown](https://fletcherpenney.net/multimarkdown/) syntax out of the box! Go ahead and put MultiMarkdown tables and stuff into your posts. It'll just work.

### Webmention

Plerd supports [Webmention](https://jmac.org/webmention/), an open technology that allows websites to send simple "Hey, this page of mine contains a link to that page of yours!" messages to other websites. If the linking page employs [Microformats2](http://microformats.io) metadata, then the target page can choose to display salient information about the mention, such as its author, or a summary of its content. It can adjust the format of this display depending upon the mention's apparent type -- a "like", a repost, a comment-style response, and so on.

With certain options enabled, Plerd can send webmentions to websites that your blog posts link to. Consult the documentation of the `plerdwatcher` and `plerdall` programs for details about Webmention-related options.

## A note about encoding

Plerd assumes that all your source and template files are encoded as UTF-8.

## Support

To report bugs or file pull requests, visit [Plerd's GitHub repository](https://github.com/jmacdotorg/plerd).

To keep up to date on Plerd news, follow [the Plerd blog](https://plerd.jmac.org).

You can also [email me, Jason McIntosh](mailto:jmac@jmac.org), directly. I am always interested to hear about other folks making use of Plerd, and I will do whatever I can to help them with it. All such feedback does tend to make the software that much better, after all!

[Plerd has a homepage at its creator's website.](http://jmac.org/plerd)

## See Plerd at work

This software powers Jason McIntosh's blog, [Fogknife](http://fogknife.com), for which it was originally written.

## Credits

Plerd is by Jason McIntosh (jmac@jmac.org). I would love to hear any thoughts about Plerd you would care to share, and welcome any questions or suggestions about it.

Contributors include:

- Petter Hassberg
- Joe Johnston
- Christian Sánchez
- David Turner
- Rebecca Turner

This repository contains the image "Envelope" designed by Jon Testa, and the image "RSS" designed by [useiconic.com](https://thenounproject.com/useiconic.com). Both are shared through a [Creative Commons Attribution 3.0 United States](https://creativecommons.org/licenses/by/3.0/us/) license, and come to this project via [The Noun Project](https://thenounproject.com).

## AI disclosure

Beginning in version 1.900, the following parts of this project include text that has been generated by LLM-based coding assistants:

- Source code, including comments
- Git commit messages
- Other developer-facing text, such as the CLAUDE.md file

All LLM-generated changes are human-directed and human-reviewed.

This README file, as well as all user-facing text and art assets, is entirely human-made. The software's overall design remains solely my own, as does its ownership and authorship, aside from the human contributors mentioned above.
