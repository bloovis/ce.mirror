require "./ll"
require "./line"
require "./buffer"
require "./window"
require "./keyboard"
require "./terminal"
require "./keymap"
require "./display"
require "./basic"
require "./misc"
require "./echo"
require "./e"

def change(f : Bool, n : Int32, k : Int32) : Result
  E.curb.flags = E.curb.flags ^ Bflags::Changed
  return Result::True
end

def exception(f : Bool, n : Int32, k : Int32) : Result
  raise "Exception command executed!"
  return Result::True
end

def quit(f : Bool, n : Int32, k : Int32) : Result
  E.tty.close
  puts "Goodbye!"
  exit 0
  return Result::True
end


# Here we capture any unhandled exceptions, and print
# the exception information along with a backtrace before exiting.
begin
  e = E.new
  e.keymap.add(Kbd.ctlx_ctrl('c'), cmdptr(quit), "quit")
  e.keymap.add_dup('q', "quit")
  e.keymap.add('c', cmdptr(change), "toggle-changed-flag")
  e.keymap.add('e', cmdptr(exception), "raise-exception")

  # Create some key bindings for other modules.
  Basic.bind_keys(e.keymap)
  Misc.bind_keys(e.keymap)
  Echo.bind_keys(e.keymap)

  e.process_command_line
  e.event_loop
rescue ex
  LibNCurses.echo
  LibNCurses.nocbreak
  LibNCurses.nl
  LibNCurses.endwin

  puts "Oh crap!  An exception occurred!"
  puts ex.inspect_with_backtrace
  exit 1
end
