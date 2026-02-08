# Words

`ce` has commands that manipulate words. In EMACS the characters
that make up words can be changed by the user. In `ce`, they are
fixed, and include the upper and lower case letters, and the underline _.
This set of characters is intended more
for editing programs, but the word commands still work reasonably
when editing text.

**M-B** (**back-word**)

The backward word command moves dot backward by words, stopping
on the first character of the word. If an argument is specified, it is the
number of words over which to move. The default argument is 1.

**M-C** (**cap-word**)

This command moves forward over a word, converting all characters
in the word to lower case except the first one, which is converted to
upper case. If an argument is supplied, it must be positive, and it specifies
the number of words over which to move.

**M-D** (**forw-del-word**)

The delete word command moves dot forward by words, and kills
any characters over which it moves. If an argument is specified, it is the
number of words over which to move. The default argument is 1.

**M-F** (**forw-word**)

The forward word command moves dot forward by words, stopping
on the first non-word character. If an argument is specified, it is the
number of words over which to move. The default argument is 1.
On PC-DOS and FlexOS this function is also bound to `C-Right`.

**M-L** (**lower-word**)

This command moves forward over a word, converting it to lower
case. If an argument is supplied, it must be positive, and it specifies the
number of words over which to move.

**M-C-H** (**back-del-word**)

The backward delete word command moves backward by words, stopping
on the first character of the word, and killing as it moves. If an argument
is present, it specifies the number of words over which to move. The
default argument is 1.

**M-Rubout** (**back-del-word**)

This command is the same as **M-C-H**.
It exists only to preserve the
symmetry between the word commands and the character commands (both backspace
and rubout are backward delete character).

**M-U** (**upper-word**)

This command moves forward over a word, converting it to upper
case. If an argument is supplied, it must be positive, and it specifies the
number of words over which to move.

