# Searching and Spelling

Search commands move though the buffer, in either the forward or the reverse
direction, looking for text that matches a search pattern. Search commands
prompt for the search pattern in the echo line. The search pattern used
by the last search command is remembered, and displayed in the prompt. If
you want to use this pattern again, just hit carriage return at the
prompt.

In search strings, all characters stand for themselves, and all searches
are normally case insensitive.  The case insensitivity may be
defeated with the "fold-case"
command, described below.
The newline characters at the ends of the lines are
considered to have hexadecimal value 0A, and can be matched by a linefeed
(**Ctrl-J**) in the search string.

`ce` supports Crystal regular expressions.  Here is a very small
subset of what regular expressions allow:

* `.` (dot) matches any character

* character classes (square brackets with optional ^ negation operator)

* groups (parentheses)

* alternatives (`|`)

* `^` (start of line) and `$` (end of line)

* `?` (zero or one occurrence)

* `*` (zero or more occurrences)

* `+` (one or more occurrences)

**C-S** (**forw-search**)

Search forward, from the current location, toward the end of
the buffer. If found, dot is positioned after the matched text. If the
text is not found, dot does not move.

**C-R** (**back-search**)

Search reverse, from the current location, toward the front of
the buffer. If found, dot is positioned at the first character of the
matched text. If the text is not found, dot does not move.

**M-C-S** (**forw-regexp-search**)

Similar to **forw-search**, except that the search string is
a regular expression, and searches cannot cross line boundaries.

**M-C-R** (**back-regexp-search**)

Similar to **back-search**, except that the search string is
a regular expression, and searches cannot cross line boundaries.

**M-C-F** (**fold-case**)

Enable or disable case folding in searches, depending on the
argument to the command.  If the argument is zero, case folding
is disabled, and searches will be sensitive to case.  If the
argument is non-zero, case folding is enabled, and searches
will NOT be sensitive to case.

**M-P** (**search-paren**)

Search for a match of the character at the dot.  If the character
is a parenthesis or bracketing character, move the dot to the matching
parenthesis or bracket, taking into account nesting and C-style
comments.  A parenthesis or bracketing character is one of the
following: `(){}[]<>`

**F9** (**search-again**)

Repeat the last search command (of any type)
without prompting for a string.

**M-Q** (**query-replace**)

Search and replace with query.  This command prompts for
a search string and a replace string, then searches forward for the
search string.  After each occurrence of the search string is found,
the dot is placed after the string, and
the user is prompted for action.  Enter one of the following characters:

* **space** or **,** (comma) causes the string to be replaced, and the
next occurrence is searched.

* **.** (period) causes the string to replaced, and quits the search.

* **n** causes the string to be skipped without being replaced, and
the next occurrence is searched.

* **!** causes all subsequent occurrences of the string to be replaced
without prompting.

* **Control-G** aborts the search without any further replacements.

**M-R** (**replace-string**)

Prompt for a search string and a replacement string,
then search forward for all occurrences of the search string, replacing
each one with the replacement string.  Do
not prompt the user for
confirmation at each replacement, as in the **query-replace** command.

**M-?** (**reg-query-replace**)

Similar to **query-replace**, except that the search string is a
regular expression.  The replacement string can contain the following special sequences:

* `\0` stands for the entire matched string.

* `\n`, where `n` is a digit in the range 1-9, stands for the nth
  matched group (where groups are delineated by parentheses in the
  regular expression pattern).

* `\` followed another `\` stands for a single `\`.

**M-/** (**reg-replace**)

Similar to **reg-query-replace**, except that the user is *not* prompted
to confirm each replacement, as in **replace-string**.

**C-X I** (**spell-region**)

This command uses `ispell` to spell-check the current region
(the text between the mark and the dot).  At each misspelled
word, `ce` pops up a window showing the suggested replacements,
and prompts for an replacement:

* Entering a blank string ignores the misspelled word
and adds it to ispell's list of words to ignore in the future.

* Entering a number replaces the misspelled word with the matching
suggested replacement in the popup window.

* Entering any other string replaces the misspelled word with that string.

* Entering `Ctrl-G` aborts the command.

**M-\$** (**spell-word**)

Similar to **spell-region**, except that it checks only the word under
the cursor.

