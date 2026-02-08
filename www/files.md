# Files

**C-X C-S, F2** (**file-save**)

This command writes the contents of the current buffer
to its associated file. The "changed" flag for the current buffer
is cleared. It is an error to use this command in a buffer which lacks
an associated file name. This command is a no-operation if the
buffer has not been changed since the last write.

**C-X C-V, F3** (**file-visit**)

This command selects a file for editing. It prompts for
a file name in the echo line. It then looks through all of the buffers
for a buffer whose associated file name is the same as the file being
selected. If a buffer is found, it just switches to that buffer.
Otherwise it creates a new buffer, fabricating a name from the last
part of the new file name, reads the file into it, and switches to the
buffer.

If the desired new buffer name is not unique (perhaps you tried to
visit a file in some other directory with the same name as a file already
read in) the command will create a buffer with a name formed by
adding a ".N" suffix, where N is a number chosen to make a unique name.

If you provide a numeric prefix to this command with `Ctrl-U`
(or just a single `Ctrl-U`), the command will mark the buffer
as read-only.  You can toggle the read-only flag with
the `toggle-readonly` command (`C-X C-Q`).

**C-X C-W** (**file-write**)

This command prompts in the echo line for a file name,
then it writes the contents of the current buffer to that file. If
the file already exists, the command prompts for overwrite confirmation.
The "changed" flag for the current buffer is reset, and the supplied file
name becomes the associated file name for the current buffer.
