# Quick Start

Here is some basic information about starting and using `ce`.

## Command Line

`ce` takes zero or more filenames as command line arguments.  It will read
all of the files, creating a buffer for each one.  It will create as many windows for the files as will fit
on the screen.  You can still navigate to the buffers that don't have a window
by using the `F8` key.

You can append a line number reference of the form `:line:column` to each filename, telling `ce`
to move the cursor to that point in the file.  The `line` and `column` are 1-based, and
the `:column` is optional.  For example, this command will open the file `src/buffer.cr`
and move to line 50, column 10:

```
ce src/buffer.cr:50:10
```

For compatibility with older programs such as `cscope`, you can also
specify a line number by preceding a filename with a `+line`
argument.  For example, this command will open the file
`src/buffer.cr` and move to line 50:

```
ce +50 src/buffer.cr
```

## Commands

`ce` implements a large subset of MicroEMACS commands.  See the section [Key Bindings](#keybindings)
below for a complete list of commands.  If you find yourself stuck while using `ce`, and
don't have time to look at the [Key Bindings](#keybindings) section, here are the most useful key
combos:

* `F1`: wait for a key, then display the command bound to that key
* `Ctrl-X` `Ctrl-K`: display all key bindings 
* `Ctrl-X` `Ctrl-S` or `F2`: save current file
* `Ctrl-X` `Ctrl-V` or `F3`: open a file
* `Ctrl-X` `Ctrl-C` or `F4`: exit the editor
* `Ctrl-X` `2`: split the window
* `Ctrl-X` `N`: move to the next window
* `Ctrl-X` `1`: make the current window the only window
* `F8`: move to the next buffer
* `F5`: undo

Using `Ctrl-G` at any prompt will abort the entry.

### Numeric Prefix

You can pass a numeric argument to a command by prefixing it with `Ctrl-U`
followed by the number in decimal.  If you don't provide a prefix, the
command will receive the default number 1.

If you provide a `Ctrl-U` prefix without a number, the command will receive
the number 4.  You can enter multiple `Ctrl-U` prefixes, each of which will
multiply the prefix by four, so that two `Ctrl-U` prefixes means 16, three means 64,
etc.

## Differences from MicroEMACS

The commands in `ce` perform nearly identically to those in MicroEMACS, but
there are some minor differences:

* When the spell commands encounter a misspelled word, they pop up a window
showing the suggested replacements.  Then they prompt you to enter your
own replacement, or type the number of one of the suggested replacements.

* Autocompletion for prompts: use the Tab key twice in a row (instead of the '?' key)
to pop up a window showing the possible completions.  Also, autocompletions
for filenames automatically choose a file if there's only one choice, instead
of waiting for you to confirm.

* The `file-write` command prompts you to confirm overwriting an existing file.

<span id="keybindings">
## Key Bindings
</span>

Here is a complete list of the key bindings in `ce`.  `C-` indicates
a Ctrl key combo; `M-` indicates an `Esc` key prefix; and `C-X` indicates
a `Ctrl X` prefix.

```
Backspace        back-del-char
C-@              set-mark
C-A              goto-bol
C-B              back-char
C-D              forw-del-char
C-E              goto-eol
C-F              forw-char
C-G              abort
C-J              ruby-indent
C-K              kill-line
C-L              refresh
C-N              forw-line
C-O              ins-nl-and-backup
C-P              back-line
C-Q              quote
C-R              back-search
C-S              forw-search
C-T              twiddle
C-V              forw-page
C-W              kill-region
C-X (            start-macro
C-X )            end-macro
C-X +            balance-windows
C-X 1            only-window
C-X 2            split-window
C-X =            display-position
C-X B            use-buffer
C-X C-B          display-buffers
C-X C-C          quit
C-X C-K          display-bindings
C-X C-N          down-window
C-X C-P          up-window
C-X C-Q          toggle-readonly
C-X C-S          file-save
C-X C-V          file-visit
C-X C-W          file-write
C-X C-X          swap-dot-and-mark
C-X C-Z          shrink-window
C-X D            dired
C-X E            execute-macro
C-X G            goto-line
C-X I            spell-region
C-X K            kill-buffer
C-X N            forw-window
C-X P            back-window
C-X Return       echo
C-X Tab          file-insert
C-X U            undo
C-X Z            enlarge-window
C-Y              yank
C-Z              back-page
Del              forw-del-char
Down             forw-line
F1               help
F10              back-buffer
F2               file-save
F3               file-visit
F4               quit
F5               undo
F6               ruby-string
F7               redo
F8               forw-buffer
F9               search-again
Home             goto-bol
Kend             goto-eol
Left             back-char
M-!              reposition-window
M-$              spell-word
M-+              indent-region
M-/              reg-replace
M-<              goto-bob
M->              goto-eob
M-?              reg-query-replace
M-B              back-word
M-Backspace      back-del-word
M-C              cap-word
M-C-F            fold-case
M-C-R            back-regexp-search
M-C-S            forw-regexp-search
M-C-U            unicode
M-C-V            display-version
M-D              forw-del-word
M-F              forw-word
M-I              set-save-tabs
M-J              fill-paragraph
M-L              lower-word
M-P              search-paren
M-Q              query-replace
M-R              replace-string
M-Tab            set-tab-size
M-U              upper-word
M-W              copy-region
M-X              extended-command
M-[              back-paragraph
M-]              forw-paragraph
M-{              back-paragraph
Pgdn             forw-page
Pgup             back-page
Return           ins-nl
Right            forw-char
Up               back-line
```
