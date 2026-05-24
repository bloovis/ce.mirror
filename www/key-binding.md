# Key Binding Commands

There are several commands in `ce` that can be used to examine
or change key bindings.  Some these commands are not normally
bound to a particular key.  As with any unbound commands (also
called "extended" commands),
they can be used by entering **M-X** (`ESC X`),
then typing the command name
in response to the prompt `:` on the echo line.

**[unbound]** (**display-bindings**)

This command creates a pop-up window that contains
a table of the current keyboard bindings.  Each entry in the table
contains the key name, and the name of the command that the key invokes.

**[unbound]** (**bind-to-key**)

This command prompts the user with `Commmand:` for
a command name, then prompts with `Key:` for a key (or key combination).
The command is then bound to that key, so that
all subsequent uses of that key cause the associated command to be
executed.  The command name can be any of those listed by the
**display-bindings** command, or any of the commands described in
this section.

**F1** (**help**)

This command waits for the user to enter a key, then displays
on the echo line the command name that is bound to that key.
