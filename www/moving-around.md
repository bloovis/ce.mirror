# Moving Around


**C-@**,**C-space**,**M-space** (**set-mark**)

Set the value of the mark to be equal to the dot.
Use this command to mark the beginning of a region of text to be
operated on by a region command such as **C-W**.
You can also use this command to mark
current location so it can be returned to later by **C-X C-X**.
This command also pushes the new value of the mark onto a 16-entry
ring of marks for the current window.

If you precede this command
with an argument (i.e., precede it with a **C-U**),
it sets the dot to the most recent mark that was stored in the ring,
and moves that mark to the end of the ring.  It also sets the mark to the next most recent
mark in the ring, if any.
By repeatedly using this command with an argument, you can cycle through
the entire ring of marks, returning to those marked locations in sequence.

**C-X C-X** (**swap-dot-and-mark**)

Exchange the positions of the dot and the mark.
This is useful for switching back and forth between two points in a file.

**C-A** (**goto-bol**)

Move to the beginning of the current line. Any argument
is ignored. Always succeeds.
On PCs, this function is bound to the `Home` key.

**C-B** (**back-char**)

Move backwards character by character. The number of characters
to move is specified by the argument. If no argument is given it moves
backwards by 1 character. A newline counts as a single character. Fails
if executed at the beginning of the buffer.
On PCs, this function is bound to the `Left` arrow key.

**C-E** (**goto-eol**)

Move to the end of the current line. Any argument is ignored.
Always succeeds.
On PCs, this function is bound to the `End` key.

**C-F** (**forw-char**)

Move forwards character by character. The number of characters
to move is specified by the argument. If no argument is given it moves
forwards by 1 character. A newline counts as a single character. Fails
if executed at the end of the buffer.
On PCs, this function is bound to the `Right` arrow key.

**C-N** (**forw-line**)

Move forward by lines. Attempt to preserve the current horizontal
position. The number of lines to move is specified by the argument. If no
argument is given it moves by 1 line. Fails if executed at the end of the
buffer.
On PCs, this function is bound to the `Down` arrow key.

**C-P** (**back-line**)

Move backwards by lines. Attempt to preserve the current horizontal
position. The number of lines to move is specified by the argument. If no
argument is given it moves by 1 line. Fails if executed at the beginning of
the buffer.
On PCs, this function is bound to the `Up` arrow key.

**C-V** (**forw-page**)

Move forward by pages. If an argument is given, it specifies the
number of pages to move. If no argument is given, 1 is assumed.
A page is a group of lines about 20% smaller than a window.
If possible, dot is kept where it is; otherwise it it moved
to the middle of the new page.
On PCs, this function is bound to the `PgDn` key.

There is a compile time option that makes this command take an argument
in lines instead of screenfuls. Look in `def.h` for the gory details.

**M-V,C-Z** (**back-page**)

Move backwards by pages. If an argument is given, it specifies the
number of pages to move. If no argument is given, 1 is assumed.
A page is a group of lines about 20% smaller than a window.
If possible, dot is kept where it is; otherwise it it moved
to the middle of the new page.
On PCs, this function is bound to the `PgUp` key.

There is a compile time option that makes this command take an argument
in lines instead of screenfuls. Look in `def.h` for the gory details.

**M-<** (**goto-bob**)

Move to the beginning of the buffer. Any argument is ignored.
Dot is set to the first character of the first line in the buffer.
On PCs, this function is bound to the `Control-Home` key.

**M->** (**goto-eob**)

Move to the end of the buffer. Any argument is ignored. Dot is
set to the first character in the fake line immediately after the buffer.
The window is set to display dot near the center of the screen.
On PCs, this function is bound to the `Control-End` key.

**C-X G** (**goto-line**)

This command moves the dot to a specific line number.
If an argument is provided, the dot is moved to that line number.
If no argument is provided, the command prompts on the echo line
for a line number.
This is useful for fixing a source file using error messages produced
by a compiler.

**C-X =** (**display-position**)

This command displays information about the current position of the
dot.  The information is displayed on the echo line,
and includes
the following:

* The octal and hex values of the character at the dot.

* The current line number, in decimal.

* The current screen row and column, in decimal.

* The approximate position of the dot in the buffer,
measured as a percentage of the buffer size.

* The number of characters in the buffer.

