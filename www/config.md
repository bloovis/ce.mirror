# EditorConfig Support

`ce` supports the [EditorConfig standard](https://editorconfig.org/).  At startup, it reads
`.editorconfig` files according to the standard, and sets certain properties for
a buffer based on the filename associated with the buffer, and whether there exist
sections of `.editorconfig` file(s) that match that filename.

`ce` does not re-read `.editorconfig` files if they change during an editing
session.  You must restart `ce` to force it to re-read those files.

`ce` recognizes the following properties:

## Supported Properties

**tab_width**: if this is set, it specifies the number of spaces represented by a tab.
This affects the on-screen display of tabs.  If `ce` cannot find a value for
`tab_width`, it uses the default value of 8.  You can overwrite this value
on a per-buffer basis by using the `set-tab-size` command (bound to `M-Tab`).

**indent_size**: if this is set, it specifies the number of columns that
the indentation commands (only `ruby-indent` for now) use to add or subtract
a level of indentation to a line.    If `ce` cannot find a value
for `indent_size`, it uses the default value of 2.

**indent_style**: if this is set to `tab`, indentation commands (only `ruby-indent`
for now) use a combination of tabs and spaces to achieve indentation.  If
it is set to `space`, only spaces are used for indentation.  If `ce` cannot find a value
for `indent_style`, it uses the default value of `tab`.

**insert_final_newline**: if this is set to `true`, when saving a file `ce` will ask the user
if a newline should be added to the end of the file if one does not already exist.
  If `ce` cannot find a value for `insert_final_newline`, it uses the default value of `true`.

**trim_trailing_whitespace**: if this is set to `true`, when saving a file `ce` will remove
trailing whitespace from each line.  If `ce` cannot find a value for `trim_trailing_whitespace`,
it uses the default value of `false`.  This property should be used with care, because
in some file formats, such as Markdown, trailing whitespace can have specific intended
meaning.

**end_of_line**: if this is set, it defines what character(s) `ce` will use as the line
separator when loading or saving files.  If it is set to `lf`, the ASCII linefeed character
is the line separator.  If it is set to `crlf`, the ASCII carriage return/linefeed combo
is the line separator.  If it is set to `cr`, the ASCII carriage return
character is the line separator.  If `ce` cannot find a value for `end_of_line`,
it uses the default value of `lf`.

**charset**: if this is set, it defines the character set that `ce` uses when loading or saving
files.  The supported character sets are `latin1`, `utf-8`, `utf-16be`, and
`utf-16le`.  If the value is any other character set, or if `ce` cannot find a value for `charset`,
it uses the default value of `utf-8`.  (Internally, `ce` uses the `utf-8` character set,
and converts from/to the specified character set when loading or saving files.)

`ce` ignores any other properties that it finds in `.editorconfig` files.

## Example

Here is the `.editorconfig` file that I use for Crystal projects:

```
root = true

[*.cr]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = tab
indent_size = 2
trim_trailing_whitespace = true
tab_width = 8
```

This config file applies only to files matching
the pattern `*.cr` in the current directory or any of its subdirectories.
For each matching file:

* The character set is `utf-8`.
* The line separator character is a linefeed.
* The indentation size is set to 2 characters.
* Indentation uses tabs.
* The tab size is set 8 characters.
* When saving the file, `ce` will ask the user if a newline needs
to be added to the last line if a newline is not present, and it will trim trailing
whitespace from each line.
