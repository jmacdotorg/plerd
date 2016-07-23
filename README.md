# Plerd

Plerd is meant to be an ultralight blogging platform for Markdown fans that plays well with (but does not require) Dropbox.

It allows you to compose and maintain blog posts as easily as adding and modifying Markdown files in a single folder. Plerd creates an entirely static website based on the content of this one folder, automatically updating the site whenever this content changes.

## Purpose

Plerd allows a blogger to publish new posts to their blog simply by adding Markdown files to a designated blog-source directory. By mixing in Dropbox, this directory can live on their local machine. They can also update posts by updating said files, and unpublish posts by deleting or moving files from that same folder.

The generated website comprises a single directory containing only static files. These include one "permalink" HTML page for every post, a recent-posts front page, a single archive page (in the manner of [Daring Fireball](http://daringfireball.net/archive)), and a syndication document in Atom format. All these are constructed from simple, customizable templates.

That's it! That's all Plerd does.

If you have the time and inclination, you may watch [a 20-minute presentation about my reasons for creating Plerd](http://blog.jmac.org/2015-06-09-my-yapcna-2015-talk-about-blogging.html).

## Project status

Plerd is released and stable. It still has plenty of room for improvement, and I welcome community feedback and patch proposals, but it will continue to do what it does now, in more or less the same fashion, for the foreseeable future.

## Setup

### Installation

This version of Plerd is intended to run directly from its own source directory, rather than from a formally installed location on your system. You will likely need to install its various library dependencies, however, and you'll need to do a little bit of further configuration and customization.

To install Plerd's dependencies, run the following command from the top level of your Plerd repository (the directory that contains this here README file):

    curl -fsSL https://cpanmin.us | perl - --installdeps .
    
This should crunch though the installation of a bunch of Perl modules that Plerd needs. It'll take a few minutes. When it's all done, Plerd will be ready for configuration.

### Configuration

1. Create a new directory for Plerd's sake. Then, create these subdirectories inside of it:

    * `source`: This will hold your blog's Markdown-based source files.
    * `templates`: Holds your blog's templates.
    * `docroot`: Will hold your blog's actual docroot, ready for serving up by the webserver software of your choice.
    
    You can freely add other files or directories in this directory if you wish (a `drafts` folder, perhaps?). Plerd will happily ignore them.
    
    *Alternately*, you can simply choose three directories anywhere on your  filesystem to serve these purposes. Just make sure that whatever user runs Plerd's processes has write access to both the source and docroot directories.

1. Copy `conf/plerd_example.conf` to `conf/plerd.conf`, and then update it to best suit your blog. 

    * Set the `path` attribute to the full path of the directory you created in the first step.
    
        (If you took the alternate route of choosing different directories, then set the `source_path`, `publication_path`, and `template_path` directories instead, just like the commented-out lines in `conf/plerd_example.conf` demonstrate.)
    
    * Set the other attributes as should be obvious, based on the provided examples.

1. Copy the contents of this repository's `templates` directory into the new `templates` subdirectory you created in the first step.

    These are sample templates that you can customize as much as you'd like. They are rendered using [Template Toolkit](http://www.template-toolkit.org). You can't change these template files' names, but you can add new sub-template files that the main temlates will invoke via [the [% INCLUDE %] directive](http://www.template-toolkit.org/docs/manual/Directives.html#section_INCLUDE), and so on.

1. Configure the webserver of your choice such that it treats the synced `docroot` subdirectory (which you created as part of the first step) as your new blog's own docroot.

    Plerd does not provide a webserver; it simply generates static HTML & XML files, ready for some other process to serve up.

## Usage

### Running Plerd

Plerd includes two command-line programs, both found in this distribution's `bin` directory:

* __plerdall__ creates a new website in Plerd's docroot directory, based on the contents of its source and templates directories.

    Run this program (with no arguments) to initially populate your blog's docroot, and at any other time you wish to manually regenerate your blog's served files.

* __plerdwatcher__ runs a daemon that monitors the Dropbox-synced source directory for changes, republishing files as necessary.

    ___This is where the magic happens.___ While both _plerdwatcher_ and Dropbox's own daemon process run on your webserver's machine, any changes you make to your blog's source directory will instantly update your blog's published static files as appropriate.
    
    Launch plerdwatcher through this command (assuming your working directory is Plerd's top-level directory):
    
        bin/plerdwatcher start
    
    It also accepts the verbs `stop`, `restart`, and `status`, as well as [all the command-line options listed in the App::Daemon documentation](https://metacpan.org/pod/App::Daemon#Command-Line-Options).

### Composing posts

To start writing a new blog post, just create a new Markdown file somewhere _outside of your blog's source directory_. (Recall that any change to the source directory instantly republishes the blog, something you won't want to do with a half-written entry on top.) You can name this file whatever you like, so long as the filename ends in either `.markdown` or `.md`.

You must also give your post a title, sometime before you're ready to publish it. You define the title simply by having the first line of your entry say `title: [whatever]`, followed by two newlines, followed in turn by the body of your post.

For example, a valid, ready-to-publish source file could be called `today.markdown`, and it could contain this, in full:

    title: My day today

    I had a pretty good day today. 
    
    I hung out at [the coffee shop](http://empireteaandcoffee.com). Then I went home.

    Well, that's all for now. Bye bye.

### Publishing posts

To publish a post, simply move it to Plerd's source directory. (Take care not to overwrite an older post's source file that may have the same name.)

Plerd will, once it notices the new file, give the file a timestamp recording the date and time of its publication. This timestamp will appear in its own line, after the title line.

Normally, Plerd will set the publication time to the moment that you added the file to the source directory. Plerd recognizes two exceptions to this rule:

* If you manually give your post a `time:` timestamp, and it's in W3C date-time format, then Plerd will leave that timestamp alone.
    
* If you leave the timestamp out, _and_ include in your post's filename a date of yesterday or earlier (e.g. `1994-06-10-i-like-ace-of-base.md`), then Plerd will set the post's timestamp to midnight (in the local time zone) of that date. This allows you to batch-backdate many posts at once -- useful, perhaps, for populating a new blog with existing writing.

(Note that Plerd assumes you use a text editor smart enough to see that the source file has both moved and had additional lines added to it from an external process, and to react to this in a graceful fashion.)

Once it has prepared the source file, Plerd will update the blog. It will create a new HTML file for the new entry, and add a link to it from the `archive.html` page. It will also appear in the recent-posts sidebar of every other entry, as well as the Atom document (unless you decided to manually backdate the entry by specifying your own date attribute within the file).

### Updating or deleting posts

To update a blog post, just edit its source Markdown file, right in the source directory. Any changes you make will immediately update your published blog as appropriate

To unpublish a blog post, simply move it out of the synced source directory -- or just delete it.

## Using Plerd with Dropbox

Plerd loves Dropbox! (Indeed it had Dropbox affinity in mind from the beginning of its design.)

To have Plerd work with Dropbox, just place its working directory (the one containing the source, docroot, and template subdirectories) somewhere in your synced Dropbox folder, and specify the local path to this folder (from your webserver's point of view) in your Plerd config file.

Now, you can create, update, and delete blog posts just by moving and editing files, _no matter what computer you're using_, so long as it has access to that Dropbox folder.

In this way you could, for example, compose and edit blog posts via Markdown in your favorite text editor while sitting by the fire with your laptop in the back of your favorite coffee shop, publishing updates to your blog by hitting _File &rarr; Save_ in your text editor, and not directly interacting with your webserver (or, indeed, with the Plerd software itself) in any way. [What what.](https://vine.co/v/OB5j0jdn1Pt)

## Support

To report bugs or file pull requests, visit [Plerd's GitHub repository](https://github.com/jmacdotorg/plerd).

[Plerd has a homepage at its creator's website.](http://jmac.org/plerd)

## See Plerd at work

This software powers [Jason McIntosh's blog at jmac.org](http://blog.jmac.org), for which it was written.

## Author

Plerd is by Jason McIntosh <jmac@jmac.org>. I would love to hear any thoughts about Plerd you would care to share.
