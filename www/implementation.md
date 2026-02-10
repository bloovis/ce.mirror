# Implementation Notes

`ce`, being a port of MicroEMACS, has a very similar structure.  The function names,
command names, and data structures are all identical or very close.  The chief
differences are the line and position structures.

## MicroEMACS

Here are some notes about data structures in MicroEMACS.

### Line

In MicroEMACS, buffers are linked lists of lines.  Each line contains a forward
link, a backward link, and a character buffer. This structure is allocated as a single unit.
This means that if the character buffer must be enlarged, an entirely new line structure
must be allocated, and the characters copied from the old line to the new line.
Then the old line must be deallocated.  Finally, all pointers to the changed line
line must be updated. This includes pointers in the next and previous lines, but also pointers in
the window structures.

### Window

A window contains several pointers to lines in its associated buffer: the "dot";
the "mark"; and "line", which is a pointer to the line being displayed on the top
row of the window.  When a line in the associated buffer is reallocated, all
of these pointers in the window structure must be checked in case one of them
pointed to the line that is now deallocated.

The use of line pointers to lines complicates several other things:

1. Determining the distance between two buffer locations.
2. Moving a certain number of lines backwards or forwards from a given line.
3. Determing the number of lines in a list.

These calculations require loops that step through the linked list of lines.
Item #1 is especially complicated, because given two line pointers,
it is not known immediately which line comes first in the list.  To determine
the ordering, MicroEMACS scans forwards and backwards simultaneously from
one of the lines until it hits the other line.

## CrystalEdit

Here are some notes about data structures in `ce`.

### Line

In `ce`, as in MicroEMACS, buffers are linked lists of lines, and a line
contains forward and backwards links.  But the character buffer in a line
is allocated separately from the links.  This means that if the characters
are changed, the links don't change.  This greatly simplifies operations
that operate on a single line.

In `ce`, positions are not stored as line pointers;
they are stored as line numbers.  This reduces calculations involving
distances between two lines to simple arithmetic.  However,
it complicates the mapping of a line number to a line pointer.
The brute force method involves scanning the entire linked list
until the *n*th line is found, which is a very expensive operation.

To improve the efficiency, `ce` uses a cache (a hash) of line pointers, indexed
by line numbers.  This works well until lines are added to or deleted
from a list.  Then much of the cache becomes invalid, because line numbers
after the deleted or added line are now wrong.  Because the cache isn't
ordered by line number, it must be cleared in these situations.

To prevent this from being a total disaster, `ce` tries to keep at least
one, or possibly two lines in the cache after an add or delete.  It also
handles the common cases of looking up line numbers that are one line
before after after a line already in the cache.  In those cases, `ce`
merely has to use a forward or backward link from the cached line to
get to the desired line.

# Window

As mentioned earlier, positions in `ce` are stored as line numbers.
This includes the dot, mark, and line attributes of windows.
But care has to be taken to ensure these line numbers are updated properly
when a line is inserted or deleted.  Fortunately, that is an easy
operation, which involves adding or subtracting one to line numbers
that were after the line being added or deleted.
