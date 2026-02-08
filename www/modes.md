# Modes

`ce` supports the notion of modes for use by Ruby extensions.
Modes are similar to major modes in Emacs.
A mode consists of a name (which is arbitrary) and a set of key bindings,
both of which are attached to a specific buffer.  By default,
buffers in `ce` do not have modes, but a Ruby extensions can
define a mode for a buffer in order to create key bindings specific to
that buffer.  Modes can be used to
implement features for particular types of code, or to provide
special types of buffers that are not treated solely as plain text.

## An Example

The file `dired.rb`, in the `ruby` directory of the MicroEAMCS repository,
is an example of a mode.
It implements a directory browser similar
to the dired mode in Emacs.
It provides a new command, `dired`, that is globally bound
to the keystroke **C-X D**:

```
ruby_command "dired"
bind "dired", ctlx('d')
```

It also creates three new commands but does not bind them to
keystrokes immediately:

```
ruby_command "visitfile"
ruby_command "openfile"
ruby_command "displayfile"
```

The initialization of the mode happens in the `dired` function when
you enter the keystroke **C-X D**.  This function prompts you
for a directory name, then calls `showdir` to open a view
on the directory.

The `showdir` function opens a new window with a buffer called `*dired*`,
to avoid conflict with existing buffers.  It clears any existing contents
of the buffer.  It then runs `/bin/ls -laF` to
load the buffer with a directory listing.  The first line in the
buffer contains the directory name, and each subsequent line contains
information about a file in that directory, as provided by `ls`.  If the name of a file ends
in a '/' character, that file is actually a subdirectory.  Finally,
`showdir` marks the buffer as read-only.

The `showdir` function then performs some string matching to determine
that starting column for filenames in the directory listings.
Finally, it creates a mode for the directory listing and attaches
three key bindings to it:

    setmode "dired"
    bind "visitfile", ctrl('m'), true
    bind "openfile", key('o'), true
    bind "displayfile", ctrl('o'), true

The `bind` calls create key bindings for the three new commands
that were defined earlier.  These bindings perform three distinct
actions on the file under the cursor (called the "selected" file):

* The `Enter` key opens the selected file in a new window,
  replacing the current dired window (which still exists).

* The `o` key splits the screen into two windows, one containing
  the dired buffer, and the other containing the selected file.
  It then moves the cursor to the selected file.

* The `C-O` key is similar to the `o` key, except that it does
  not move the cursor to the selected file.

You can load the dired mode support automatically by copying the file
`mode.rb` to `~/pe.rb`.
