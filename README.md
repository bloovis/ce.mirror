# ce

This is a curses-based editor written in Crystal that attempts to duplicate
the functionality of my MicroEMACS variant.  There is no good reason for me
to create such a thing, since MicroEMACS is smaller, faster, and more portable.
I'm doing it simply for my own amusement and education.

As of the time of this writing (2026-02-04), `ce` implements enough
MicroEMACS functionality to perform basic editing, including undo,
keyboard macros, and Ruby extensions.  My hope is that the Crystal
code will be easier to understand and modify than the C code in MicroEMACS.

## Ruby Extensions

`ce` supports Ruby extensions using the same RPC system that I
implemented in MicroEMACS.  For this to work, use `sudo` to copy
`ruby/server.rb` from my MicroEMACS repository to the directory
`/usr/local/share/pe` (create that directory if it does not exist).
Then copy the desired Ruby extension from the `ruby` directory in my
MicroEMACS repository to `.pe.rb` in your working directory.

## Missing Features

The following features from my MicroEMACS variant are missing in `ce`, but
I may add them as needed:

* the ability to name macros or save them in text form
* profiles (loadable macros in text form)
* mark rings (I have never used this feature)
* line numbers
* frames (for multiple native windows)
* cscope support
* upper- and lower-case a region (I have never used this feature)
* incremental search (I have never used this feature)

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

* `F1`: wait for a key, then display the command bound to that key
* `Ctrl-X` `Ctrl-K`: display all key bindings 
* `Ctrl-X` `Ctrl-S` or `F2`: save current file
* `Ctrl-X` `Ctrl-V` or `F3`: open a file
* `Ctrl-X` `Ctrl-C` or `F4`: exit the editor
* `Ctrl-X` `2`: split the window
* `Ctrl-X` `N`: move to the next window
* `Ctrl-X` `1`: make the current window the only window
* `F8`: move to the next buffer
* `F5`: undo

Using `Ctrl-G` at any prompt will abort the entry.

Eventually I will provide more complete documentation, but for now
you can use my MicroEMACS documentation as a guide.

## Contributors

- [Mark Alexander](https://github.com/bloovis) - creator and maintainer
