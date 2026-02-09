# Inserting

All Unicode (UTF-8) characters, and ASCII characters between hexadecimal 20 and 7E (blank through tilde),
are self-inserting. They are inserted into the buffer at the current
location of dot, and dot moves 1 character to the right.

The **Tab** (or **C-I**) key is also self-inserting.
By default, `ce` has fixed tab settings at columns 9, 17, 25, and so on,
but you can change the tab width using the **set-tab-size** command.

Any self-inserting character can be given an
argument.
This argument is
used as a repeat count, and the character is inserted that number of
times. This is useful for creating lines of `*` characters of a specific
length, and other pseudo-graphic things.

Self-inserting keys are all bound to the
function **ins-self**.  As with
any key, these keys can be rebound to other functions, but this is not
always advisable.

**C-M, Return** (**ins-nl**)

The Return key works just like you would expect it to work;
it inserts a newline character. Lines can be split by moving into the middle
of the line, and inserting a newline.

**C-J** (**ruby-indent**)

This command attempts to indent
according to commonly accepted Ruby conventions.
It inserts a new line, and then inserts enough tabs and spaces to
produce the proper indentation based on the previous line.
If the previous line starts with `{` or one of the many block-start keywords, or an argument
of four (i.e. a single `Ctrl-U`) is specified, increase indentation by two spaces. If an
argument of 16 (i.e. two `Ctrl-U`s) is specified, reduce indentation by two
spaces.  Otherwise retain the same indentation.

**C-O** (**ins-nl-and-backup**)

This command creates blank lines. To be precise, it inserts
a newline by doing a **C-M**,
and then backs up by doing a **C-B**. If dot is at
the start of a line, this will leave dot sitting on the first character
of a new blank line.

**C-Q** (**quote**)

Characters which are special to `ce` can be inserted by
using this command.
The next character after the **C-Q** is stripped of
any special meaning. It is simply inserted into the current buffer.
Any argument specified on the **C-Q**
command is used as the insert
repeat count.

**C-T** (**twiddle**)

Exchange the two characters on either side of the dot.
If the the dot is at the end of the line, twiddle the two characters
before it.  Does nothing if the dot is at the beginning of the line.
This command is supposedly useful for correcting common
letter transpositions while entering new text.

**M-Tab** (**set-tab-size**)

Set the tab size to the value of the argument, which must be
a positive number greater than 1 (the default tab size is 8).
This only affects the how
`ce` displays tabs on the screen; it does not affect
how tabs are saved when a file is written to disk.  To change
how `ce` handles tabs when saving a file, see the
**set-save-tabs** command.

**M-I** (**set-save-tabs**)

By default, `ce` preserves tabs when it writes
a file to disk.  If you pass a zero argument to this
command, `ce` will convert tabs to spaces when
writing a file; the number of spaces is determined
by the tab size (which you can set using **set-tab-size**).
If you pass a non-zero argument to this command,
`ce` will revert back to the default behavior,
which is to preserve tabs.
