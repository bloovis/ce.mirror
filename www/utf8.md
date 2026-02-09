# UTF-8 and Unicode

`ce` supports reading and writing text files
encoded with UTF-8, a byte-oriented encoding of Unicode.  UTF-8 can
be thought of as a superset of ASCII: bytes less then 0x80 are
identical to ASCII, and bytes greater than or equal to 0x80 are always
parts of UTF-8 sequences.  UTF-8 characters vary in length from
one byte (ASCII) to six bytes, though four bytes is the longest
typically seen.

Internally, `ce` stores lines of text in their original
UTF-8 encoding, but displays multibyte UTF-8 sequences to the user
as single Unicode characters in the range 0x80 to 0xffff.  Unicode
characters greater then 0xffff are not supported; in practice
these characters are extremely rare.

For the most part, `ce` is able to display UTF-8 characters 
correctly, with the exception of non-spacing or combining characters.
The display of these characters is undefined: sometimes they show up
as modifiers of subsequent characters, or as blanks, or as a lowercase
'x' with a modifier.

On Linux, most terminal programs support a standard method for
entering Unicode characters at the keyboard: hold down Ctrl and Shift,
then press and release 'u', then release Ctrl and Shift, then enter
the hex digits of the Unicode character followed by the Enter key.
This method works when entering characters at prompts in the echo line,
or while entering text in the edit buffer.

If this method doesn't work, you can still enter Unicode characters
in the edit buffer using the following command:

**M-C-U** (**unicode**)

This command prompts you to enter a line of text containing the hexadecimal
values of one or more Unicode characters.  The hex values must
not have a '0x' prefix, or any other prefix, and must be
separated by spaces.  `ce` will then insert the corresponding UTF-8
characters into the current buffer.

As an example, entering the string `e0 e1 e2` would insert the characters
`àáâ` into the buffer.
