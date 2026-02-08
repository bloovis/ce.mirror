# Buffer Management


Previous sections have made references to the text in "the buffer",
which implied that there is only one buffer. This is not true; `ce`
allows any number of buffers, memory space permitting.

Each buffer has its own buffer name (a 16 character string),
and optional associated file name,
and a block of text. A value of dot and mark
is also associated with
any buffer that is not currently being displayed. This remembered value
of dot and mark makes a buffer come back in approximately the same state
as it was when it was hidden.

Also associated with each buffer is a changed flag.
This flag is set
when the text in the buffer is modified, and reset when the text in the
buffer is written out to its associated file. `ce` will always ask
for confirmation before executing a command that would cause changed
text to be lost.

**C-X C-B** (**display-buffers**)

This command creates a pop-up window on the screen, and displays in it the following
information for each buffer:

* The "changed" flag, indicating whether the buffer has changed since the last save
* The number of windows viewing this buffer
* The "system" flag, indicating whether this is a "system" buffer not managed by the user
* The size of the buffer in bytes (not characters)
* The name of the buffer
* The filename associated with the buffer.

You can edit the text of the buffer in the popup window,
but `ce` won't check if it's been modified when you quit. 
ce` makes no attempt to update the popup window as other buffers are edited;
however, another **C-X C-B** command will cause the window to be updated in place.

**C-X B** (**use-buffer**)

This command prompts for a buffer name, and then switches
the buffer being displayed in the current window to that buffer. The
buffer will be created if it does not exist.

If you do not enter a buffer name, this command will use the name of the
last buffer that you switched from with **C-X B**.  Thus, you can
use **C-X B** repeatedly to switch between two buffers without entering
their names each time.

**F8** (**forw-buffer**)

This command switches the buffer being displayed to the next buffer
in the buffer list.
If the end of the buffer list is reached, switch
to the first buffer in the list.  The list of buffers can be displayed
with **C-X C-B**. 

**F10** (**back-buffer**)

This command is similar to **forw-buffer**, except that it
switches the buffer being displayed to the previous buffer
in the buffer list.

**C-X K** (**kill-buffer**)

This command prompts for a buffer name, and then destroys
the buffer with that name. It will ask for permission to destroy the
buffer if the text has been changed since it was written to the associated
file. You cannot delete a buffer that is being displayed.

**C-X C-Q** (**toggle-readonly**)

This command toggles the read-only flag on the current buffer:
if the buffer is currently read-only, it is made read-write;
otherwise it is made read-only.  This can be useful to counteract
the effect of [starting `ce`](starting.md) with the `-r` option.
