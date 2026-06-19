# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Plerd is an ultralight static-blog generator written in Perl (Moose-based). It turns a directory of Markdown source files into a complete static site (per-post HTML, a recent-posts front page, a single archive page, tag pages, and Atom + JSON Feed syndication documents). It is designed to pair with Dropbox: a daemon watches the source directory and republishes on change. Distributed on CPAN as `Plerd`.

Source code lives in `lib/` and `bin/`.

## Commands

Dependencies: `cpanm --installdeps .` (deps are listed in `cpanfile`).

Build / install (ExtUtils::MakeMaker is the canonical maker per `minil.toml`):

```
perl Makefile.PL && make && make install
```

Tests (they add `../lib` via FindBin, so run with `-l`):

```
prove -lv t/                 # whole suite
prove -lv t/basic.t          # a single test file
```

`t/basic.t` is the main end-to-end test: it calls `Plerd::Init::initialize` to scaffold `t/testblog/`, copies fixtures from `t/source_model/` (filenames containing `TODAY` get the current date substituted), publishes, and asserts on the generated files. `t/daemon.t` covers `plerdwatcher`; `t/init.t` covers scaffolding.

## Development workflow

This project follows test-driven development. Whenever appropriate, begin work on a new feature or bug fix by writing a test that captures the desired behavior, and run it first to confirm it *fails* for the expected reason. Then implement the change and confirm the test passes.

(The fail-first step only applies when the test genuinely precedes the implementation. If a change has already landed and you are adding tests retroactively, just confirm the new tests pass — don't revert working code to manufacture a failing run.)

Run the two CLI programs from the distribution root (they resolve `lib/` via FindBin):

```
bin/plerdall --init=/path/to/new/blog   # scaffold a new blog instance
bin/plerdall                            # publish the whole blog once
bin/plerdwatcher start                  # daemon: watch source dir, republish on change
```

`bin/plerdwatcher` also accepts `stop`/`restart`/`status` and all App::Daemon options.

## Configuration resolution

Both CLIs read a YAML config via `Plerd::Util::read_config_file`. When `--config` is not given, it searches in order: `./plerd.conf`, `./conf/plerd.conf`, `~/.plerd`, then `$bin/../conf/plerd.conf`. The config keys map directly onto `Plerd->new` attributes. Required: `title`, `base_uri`, `author_name`, `author_email`, and either `path` (a directory containing `source/`, `templates/`, `docroot/`, `db/` by those exact names) or each `*_path` set individually.

## Architecture

The publish pipeline is small and flows through three Moose classes in `lib/`:

- **`Plerd`** (`Plerd.pm`) — the blog object and orchestrator. `publish_all` is the entry point: it builds the `posts` arrayref (sorted newest-first), publishes each post, then generates tag pages, the archive page, the recent page (with an `index.html` symlink), and the Atom/JSON feeds. Almost every path/file/directory is a `lazy_build` attribute, and `_build_subdirectory` derives `source`/`db`/`docroot`/`templates` locations from either an explicit `*_path` or the parent `path`. After publishing, it clears the post caches and tag maps (via `_clear_caches`) so the object can be reused (important for the long-running daemon). `publish_file($source_file)` is the incremental entry point used by the daemon for `create`/`modify` events: it MD5-hashes the file's metadata block and compares it against the `db/posts.json` index (basename → `{ hash, time }` record). A missing/changed hash means metadata may affect shared pages, so it falls back to `publish_all` and rewrites the whole index. An unchanged hash means a body-only edit, so it republishes that post's page — and refreshes the recent page and feeds *only if* the post is in the recent set (so a body edit to an old, out-of-feed post rewrites that one page and nothing else). The incremental path never builds the full `posts` list: ordering, recency (`_recent_basenames`), and a post's prev/next neighbors (`neighbor_basename`, used by `Post`'s `_build_newer_post`/`_build_older_post` when `has_posts` is false) all read the index, and `_build_recent_posts` constructs only the recent posts — so render cost is O(recent set), not O(blog). Because `_process_source_file` rewrites the source on first publish, the index is always recomputed *after* `publish_all`, not before.

All publication writes are atomic: `_publish_template_to_file`/`_atomically_write` render to a `File::Temp` file in the target's own directory, then `rename()` it into place (and the `index.html` symlink is swapped via a temp link), so a web server never sees a half-written or zero-length file and a failed render leaves the prior file intact.

- **`Plerd::Post`** (`Post.pm`) — one post per Markdown source file. The real work happens in `_process_source_file`, fired by a Moose **trigger** the moment `source_file` is set (not lazily). That method:
  - parses the leading `key: value` metadata block (terminated by a blank line) into `attributes`, then the Markdown body;
  - runs the body and title through `Text::MultiMarkdown::markdown` then `Plerd::SmartyPants`;
  - **mutates the source file in place** — if `time`, `published_filename`, or `guid` are missing, it computes them and rewrites the file with the full metadata block. This write-back is core behavior, not a side effect to "fix." Date logic: explicit W3C `time:` wins; else a `YYYY-MM-DD` filename prefix sets midnight of that date (or now, if the date is today); else now.
  - resolves tags (comma-separated `tags:` header) into shared `Plerd::Tag` objects via `$plerd->tag_named`.
  - `publish` renders `post.tt`. `send_webmentions` walks the post's links via `Web::Mention`.

- **`Plerd::Tag`** (`Tag.pm`) — a tag shared across posts. Keyed case-insensitively in `Plerd`'s `tags_map`; `ponder_new_name` and `Plerd`'s `tag_case_conflicts` machinery detect/warn when the same tag appears with inconsistent capitalization.

Supporting modules: **`Plerd::Util`** (config-file loading only), **`Plerd::Init`** (scaffolds a new blog directory with sample templates/config), **`Plerd::SmartyPants`** (vendored typographic-punctuation filter).

### Templating

Output is [Template Toolkit](http://www.template-toolkit.org). `Plerd->_build_template` configures one `Template` object with `INCLUDE_PATH` = the blog's `templates/` dir, UTF-8 encoding, and a custom `json` filter. Templates live in the *generated blog instance*, not in `lib/` — the canonical samples are emitted by `Plerd::Init`. Key files: `post.tt` (also reused for the recent/front page), `archive.tt`, `atom.tt`, `jsonfeed.tt`, `tags.tt`. Templates receive the `plerd` object plus `posts`, and post pages also get `context_post`.

### Encoding

Everything is UTF-8. Source/template reads and publication writes all open with explicit `:encoding(utf8)` / `:utf8` layers — preserve these when touching file I/O.

### Webmention

Webmention *sending* is a supported feature (`--send-webmentions` on either CLI). Webmention *receipt/storage* was removed in 1.900; both CLIs intentionally `die` if the old `--receive-webmentions` / `--process-webmentions` / `--rebuild-webmentions` options are passed.
