# Paragraphs

`ce` has commands that deal with paragraphs.  A paragraph
is a sequences of text lines, where  a text line is a line that starts
with zero or more spaces followed by
a word character, and a  word character is a letter or underscore.
Paragraphs are separated by non-text lines.

There are commands for "filling" a paragraph, moving dot to
the start or end of a paragraph, and setting the fill column.

**[unbound]** (**set-fill-column**)

This command sets the current fill column to its argument
(remember that the argument is entered as `Control-U` and a
decimal number preceding the command).  If no argument is present,
the column of the current location of the cursor (the dot) is used instead.
The fill column is used by the **fill-paragraph** command.
The default fill column is 72.  TODO.

**M-[** (**back-paragraph**)

This command moves the dot to the beginning of the current paragraph.
If the dot is not in a paragraph when this command is entered,
it is moved to the beginning of the preceding paragraph.
If an argument is provided, the dot is moved by that many paragraphs.

If you are using `ce` with a serial terminal, you may have
to type `ESCAPE` followed by two `[` characters to invoke this command.
The reason is that ESCAPE-[ is the prefix produced by
function keys on VT-100 compatible terminals.

**M-]** (**forw-paragraph**)

This command moves the dot to
the end of the current paragraph (actually to first separator line after
the paragraph).
If the dot is not in a paragraph when this command is entered,
it is moved to the end of the following paragraph.
If an argument is provided, the dot is moved by that many paragraphs.

**M-J** (**fill-paragraph**)

This command "fills" the current paragraph.  It inserts or
deletes spaces and line breaks between words as needed to cause
the text of each line to be filled out to (but no farther than)
the current fill column.  The text is thus filled, but not
right-justified.  The dot is then placed at the end of the
last line of the paragraph.
