# ce

This is a curses-based editor written in Crystal that attempts to duplicate
the functionality of my MicroEMACS variant.  There is no good reason for me
to create such a thing, since MicroEMACS is smaller, faster, and more portable.
I'm doing it simply for my own amusement and education.

As of the time of this writing (2026-02-13), `ce` implements enough
MicroEMACS functionality to perform basic editing, including undo/redo,
keyboard macros, and Ruby extensions.  My hope is that the Crystal
code will be easier to understand and modify than the C code in MicroEMACS.

`ce` has a compiled code size of about 3 Mb.  This is much larger than
the 110 Kb code size of MicroEMACS, and is likely due to the inclusion
of the very large Crystal standard library.  But it is still much
smaller than editors in use by the Cool Kids these days.  For example,
the very popular [zed](https://github.com/zed-industries/zed) has about
300 Mb of code.  I've heard that VS Code is similarly huge,
though I have not examined the binaries myself.  Of course, these popular editors
are much more feature-rich, but it is questionable whether they have
100 times more utility than `ce`, or 3000 times more utility than
MicroEMACS.

## Installation

Build `ce` using this command:

```
make
```

Then copy the resulting binary file `ce` to some place in your PATH.

`ce` requires no external shards (Crystal libraries).  It does require
the `ncurses` or `ncursesw` package for your Linux distro.

To make nicely formatted API documentation for the classes and methods
in `ce`, use this command:

```
make docs
```

or this command:

```
crystal docs
```

To view the API documentation, use this command:

```
make viewdocs
```

or this command:

```
xdg-open docs/index.html
```

## Missing Features

The following features from my MicroEMACS variant are missing in `ce`, but
I may add them as needed:

* the ability to name macros or save them in text form
* profiles (loadable macros in text form)
* mark rings (I have never used this feature)
* line numbers in the display
* frames (for multiple native windows)
* cscope support
* upper- and lower-case a region (I have never used this feature)
* incremental search (I have never used this feature)
* a few other little-used commands

## Added Features

`ce` has a small set of features that aren't in my MicroEMACS variant:

* Support for EditorConfig.
* Commands for scrolling the other window.
* Command for displaying internal stats.

## User Guide

Complete usage information can be found [here](www/index.md).
