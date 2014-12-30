# Plerd

Plerd is meant to be an ultralight blogging platform for Markdown fans that plays well with Dropbox.

It allows you to compose and maintain blog posts as easily as adding and modifying Markdown files in a single, Dropbox-synced folder. Plerd creates an entirely static website based on the content of this one folder, automatically updating the site whenever this content changes.

This software is in **very early development**, currently existing in a minimum-viable-product form. Beyond being hard to install and obscure to use, its API might change dramatically while I, Plerd's creator, continue to puzzle out how it actually wants to work.

If you want something aiming towards a similar goal but rather more mature, have a look at [Letterpress](https://github.com/an0/Letterpress).

## Purpose

Plerd allows a blogger to publish new posts to their blog simply by adding Markdown files to a given Dropbox-synced directory on their local machine. They can also update posts by updating said files, and unpublish posts by deleting or moving files from that same folder.

The generated website comprises a single directory containing only static files. These include one "permalink" HTML page for every post, a recent-posts front page, a single archive page (in the manner of [Daring Fireball](http://daringfireball.net/archive)), and a syndication document in Atom format. All these are constructed from simple, customizable templates.

That's it! That's all Plerd does.

## Setup

### Installation

This version of Plerd is intended to run directly from a cloned Git repository, rather than from a formally installed location on your system. You will likely need to install its various library dependencies, however.

To install Plerd's dependencies, run the following command from the top level of your Plerd repository (the directory that contains this here README file):

    curl -fsSL https://cpanmin.us | perl - --installdeps .
    
(If you already have _cpanm_ installed, you can just run `cpanm --installdeps .` instead.)

This should crunch though the installation of a bunch of Perl modules that Plerd needs. It'll take a few minutes. When it's all done, Plerd will be ready for configuration.

### Configuration

1. Create a new directory in your Dropbox for Plerd's sake. You can name it whatever you'd like, and it can exist at any level within your Dropbox. Then, create these subdirectories inside of it:

    * `source`: This will hold your blog's Markdown-based source files.
    * `templates`: Holds your blog's templates.
    * `docroot`: Will hold your blog's actual docroot, ready for serving up by the webserver software of your choice.
    
    You can freely add other files or directories in this directory if you wish (a `drafts` folder, perhaps?). Plerd will happily ignore them.

1. Update `conf/plerd.conf` to best suit your blog. 

    * Set the `path` attribute to the full path of the Dropbox-synched directory you created in the first step.
    * Set the other attributes as should be obvious, based on the provided examples.

1. Copy the contents of this repository's `templates` directory into the new `templates` subdirectory you created in the first step.

    These are sample templates that you can customize as much as you'd like. They are rendered using [Template Toolkit](http://www.template-toolkit.org). You can't change these template files' names, but you can add new sub-template files that the main temlates will invoke via [the [% INCLUDE %] directive](http://www.template-toolkit.org/docs/manual/Directives.html#section_INCLUDE), and so on.

1. Configure the webserver of your choice such that it treats the synced `docroot` subdirectory (which you created as part of the first step) as your new blog's own docroot.

    Plerd does not provide a webserver; it simply generates static HTML & XML files, ready for some other process to serve up.

## Usage

### Running Plerd

Plerd includes two command-line programs, both found in this distributin's `bin` directory:

* __plerdall__ creates a new website in Plerd's docroot directory, based on the contents of its source and templates directories.

    Run this command to initially create your blog, and then at any future time you wish to re-create all its files (e.g. if you make changes to templates).

* __plerdwatcher__ runs a daemon that monitors the Dropbox-synced source directory for changes, republishing files as necessary.

    ___This is where the magic happens.___ While both _plerdwatcher_ and Dropbox's own daemon process run on your webserver's machine, any changes you make to your blog's source directory will instantly update your blog's published static files as appropriate.
    
    In this way you can, for example, compose and edit blog posts via Markdown in your favorite text editor while sitting by the fire with your laptop in the back of your favorite coffee shop, publishing to your blog  by hitting _File &rarr; Save_ in your text editor. [What what.](https://vine.co/v/OB5j0jdn1Pt)

### Composing posts

Plerd post-source files are just Markdown files. However, Plerd requires that every post-source file specify a date and a title for its post, which it extracts in the following ways:

* The source file's name __must__ contain its post's date in _YYYY-MM-DD_ format. (Plerd doesn't care about the time, only the date.)

* The source file's content begins with a block of directives in _key: value_ format, one per line, prior to the actual body of the post. At this time, the only directive that Plerd cares about -- and which __must__ be there -- is _title_.

Furthermore, source files' names must end in either `.md` or `.markdown`.

For example, a valid source file could be called `2010-03-01-my-day-today.markdown`, and it could contain this, in full:

    title: My day today

    I had a pretty good day today. 
    
    I hung out at [the coffee shop](http://empireteaandcoffee.com). Then I went home.

    Well, that's all for now. Bye bye.

Publishing this file will result in a three-paragraph HTML file named `2010-03-01-my-day-today.html` appearing in the blog's docroot directory. It will also get linked from `archive.html` among the posts from March, 2010, and it will furthermore appear in the recent-posts page and the Atom document if a post from March 1, 2010 represents one of your blog's ten most recent posts.

### Updating or deleting posts

To update a blog post, just edit its source Markdown file.

To unpublish a blog post, just delete its source Markdown file, or move it out of the synced source directory.

## See Plerd at work

This software powers [Jason McIntosh's blog at jmac.org](http://blog.jmac.org), for which it was written.

## Author

Plerd is by Jason McIntosh <jmac@jmac.org>. I would love to hear any thoughts about Plerd you would care to share.