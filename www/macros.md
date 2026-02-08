# Keyboard Macros

Keyboard macros simplify a large class of repetitious editing tasks.
The basic idea is simple. A set of keystrokes can be collected into a
group, and then the group may be replayed any number of times.
There is only one keyboard macro; when you define a new keyboard macro, the old one is erased.

**C-X (** (**start-macro**)

This command starts the collection of a keyboard macro. All
keystrokes up to the next **C-X )** will be gathered up,
and may be replayed by
the execute keyboard macro command.

**C-X )** (**end-macro**)

This command stops the collection of a keyboard macro.

**C-X E** (**execute-macro**)

The execute keyboard macro command replays the current keyboard
macro. If an argument is present, it specifies the number of times the macro
should be executed. If no argument is present, it runs the macro once.
Execution of the macro stops if an error occurs (such as a failed
search).
