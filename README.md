# ce

This is a curses-based editor written in Crystal that attempts to duplicate
the functionality of my MicroEMACS variant.  There is no good reason for me
to create such a thing, since MicroEMACS is smaller, faster, and more portable.
I'm doing it simply for my own amusement and education.

As of the time of this writing (2026-01-31), `ce` implements just enough
MicroEMACS functionality to perform basic editing, including undo.

## Installation

Build `ce` using this command:

```
make
```

Then copy the resulting binary file `ce` to some place in your PATH.

`ce` requires no external shards (Crystal libraries).  It does require
the `ncurses-dev` or `ncurses-devel` packages for your Linux distro.

## Usage

`ce` responds to a minimal set of MicroEMACS key bindings.  If
you find yourself stuck, here are the most useful key bindings:

* `Ctrl-X` `Ctrl-S`: save current file
* `Ctrl-X` `Ctrl-C`: exit the editor
* `Ctrl-X` `Ctrl-V`: open a file
* `Ctrl-X` `2`: split the window
* `Ctrl-X` `N`: move to the next window
* `Ctrl-X` `1`: make the current window the only window
* `F8`: move to the next buffer
* `F5`: undo

Eventually I will provide more complete documentation.

## Contributors

- [Mark Alexander](https://github.com/bloovis) - creator and maintainer
