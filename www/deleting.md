# Deleting and Killing


There are two general classes of commands that remove text from the
buffer: delete commands and kill commands.
Delete commands remove text from the buffer, and throw it away.
Kill commands remove text from the buffer, but save the text in a special
place called the *kill buffer* .
Kill commands clear the kill buffer only
if the previous command was not a kill command. Multiple kill commands
executed sequentially append text to the kill buffer.

**C-D** (**forw-del-char**)

Delete characters to the left of dot. If an argument is
specified then that number of characters is deleted. If no argument is
specified then 1 character is deleted. In addition, if an argument is
specified, the rubout command kills the text instead of deleting it.
The command fails if there is not enough text between the start of the
buffer and dot.

**C-H,Backspace** (**back-del-char**)

Delete characters to the left of dot. If an argument is
specified then that number of characters is deleted. If no argument is
specified then 1 character is deleted. In addition, if an argument is
specified, the rubout command kills the text instead of deleting it.
The command fails if there is not enough text between the start of the
buffer and dot.

**C-K** (**kill-line**)

This is the basic killing command. If there is no argument
it kills from dot to the end of the line, unless dot is at the
end of line, when it kills the end of line.
If a positive argument is specified, **C-K** kills that many lines,
including the newlines.
If an argument of 0 is specified, **C-K** kills from the start of the current
line to dot.
Finally, if a negative argument is specified, **C-K** kills backwards over
abs(arg) newlines. This command fails if there aren't enough characters
left in the buffer to be killed.

**C-W** (**kill-region**)

Kill all of the text enclosed in the region, and put it into
the kill buffer.
If an argument is specified, then delete the text instead of killing it;
this is useful
when memory fills up and `ce` can't allocate space for the
kill buffer.  The value of the argument, if any, is ignored.

**C-Y** (**yank**)

Insert the text from the kill buffer into the current buffer
at dot. If an argument is specified, it specifies the number of times
the text is yanked. If no argument is specified, yank the text back
once. Dot is advanced over the inserted text, as if the text had
been typed in normally. Always succeeds.

**M-W** (**copy-region**)

Put all of the text enclosed in the region into the kill buffer,
without deleting it from the current buffer.
This is similar to **C-W** followed by **C-Y**, except that the buffer is
not flagged as having been changed.
