# Plerd

Plerd is meant to be an ultralight blogging platform for Markdown fans that plays well with Dropbox.

This software is in **very early development**, currently existing in a minimum-viable-product form. Beyond being hard to install and obscure to use, its API might change dramatically while I, Plerd's creator, continue to puzzle out how it actually wants to work.

If you want something aiming towards a similar goal but rather more mature, have a look at e.g. [Letterpress](https://github.com/an0/Letterpress).

## Purpose

Plerd allows a blogger to publish new posts to their blog simply by adding Markdown files to a given Dropbox-synced directory on their local machine. They can also update posts by updating said files, and unpublish posts by deleting or moving files from that same folder.

The generated website comprises a single directory containing only static files. These include one "permalink" HTML page for every post, a recent-posts front page, a single archive page (in the manner of [Daring Fireball](http://daringfireball.net/archive)), and a syndication document in Atom format. All these are constructed from simple, customizable templates.

That's it! That's all Plerd does.

## Setup

At this time, you're unfortunately in the wilderness as far as installing the necessary Perl modules. (I won't consider this software actually released until I make that bit easier for everyone else.)

Create a new directory in your Dropbox for Plerd's sake, and then create these subdirectories inside of it:

* `source`: This will hold your blog's Markdown-based source files.
* `templates`: Holds your blog's templates. (Go ahead and copy the contents of this repository's `templates` file into this directory, after you create it.)
* `docroot`: Will hold your blog's actual docroot, ready for serving up by the webserver software of your choice.

You should then update `conf/plerd.conf` to taste. Set the `path` attribute to the full path of the Dropbox-synched directory Plerd will use, from the perspective of the server machine's filesystem.

And then you need to do whatever you'd like with the webserver of your choice such that it treats the synced `docroot` subdirectory as the your blog's own docroot.

## Usage

### Composing posts

Plerd post-source files are just Markdown files. However, Plerd requires that every post-source file specify a date and a title for its post, which it extracts in the following ways:

* The source file's name __must__ contain its post's date in _YYYY-MM-DD_ format. (Plerd doesn't care about the time, only the date.)

* The source file's content begins with a block of directives in _key: value_ format, one per line, prior to the actual body of the post. At this time, the only directive that Plerd cares about -- and which __must__ be there -- is _title_.

Furthermore, source files' names must end in either `.md` or `.markdown`.

For example, a valid source file could be called `2010-01-01 blah.markdown`, and it could contain this, in full:

    title: My day today

    I had a pretty good day today. 
    
    I hung out at [the coffee shop](http://empireteaandcoffee.com). Then I went home.

    Well, that's all for now. Bye bye.

Publishing this file will result in a three-paragraph HTML file named `2010-03-01-my-day-today.html` appearing in the blog's docroot directory. (Note that any part of the source file's name besides the date will be ignored.) It will also get linked from `archive.html` among the posts from March, 2010, and it will furthermore appear in the recent-posts page and the Atom document if a post from March 1, 2010 represents one of your blog's ten most recent posts.

### Publishing posts

* Run `bin/plerdall` to create a new website in Plerd's docroot directory, based on the contents of its source and templates directories.

* Run `bin/plerdwatcher` to launch a daemon that monitors the source directory for changes, republishing files as necessary.

## Working example

This software powers [Jason McIntosh's blog at jmac.org](http://blog.jmac.org). At this point it probably isn't in use anywhere else. You are quite welcome to try using it yourself if you'd like, but I haven't really done much to make that easy for you (yet).

## Author

Plerd is by Jason McIntosh <jmac@jmac.org>. I would love to hear any thoughts about Plerd you would care to share.