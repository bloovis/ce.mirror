# EditorConfig Support

`ce` supports the [EditorConfig standard](https://editorconfig.org/).  It reads
`.editconfig` files according to the standard, and sets certain properties for
a buffer based on the filename associated with the buffer, and whether there exist
sections of `.editconfig` file(s) that match that filename.

`ce` recognizes the following properties:

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

`ce` ignores any other properties that it finds in `.editorconfig` files.

Here is the `.editconfig` file that I use.  The indentation size is 2 characters;
indentation uses tabs; and the tab size is 8 characters.

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
