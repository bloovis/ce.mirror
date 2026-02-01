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
require "./files"
require "./word"
require "./region"
require "./search"
require "./undo"
require "./rubyrpc"
require "./e"

def exception(f : Bool, n : Int32, k : Int32) : Result
  raise "Exception command executed!"
  return Result::True
end

def quit(f : Bool, n : Int32, k : Int32) : Result
  # Check if there are any changed buffers.
  if Buffer.anycb
    return Result::False if Echo.yesno("There are changed buffers.  Quit") != Result::True
  end
  E.tty.close
  puts "Goodbye!"
  exit 0
  return Result::True
end

# Kills of any keyboard macro that is in progress.
def ctrlg(f : Bool, n : Int32, k : Int32) : Result
  # FIXME: end the macro here!
  return Result::Abort
end

def self.makechart
  # Populate the system buffer with the information about the
  # "normal" buffers.
  b = Buffer.sysbuf
  b.clear
  lines = [] of String
  E.keymap.k2n.each do |key, cmdname|
    if cmdname != "ins-self"
      keyname = E.kbd.keyname(key).pad_right(16)
      lines << "#{keyname} #{cmdname}"
    end
  end
  lines.sort.each { |l| b.addline(l) }
  return true
end

# This function creates a table, listing all
# of the command keys and their current bindings, and stores
# the table in the standard pop-op buffer (the one used by the
# directory list command, the buffer list command, etc.). This
# lets MicroEMACS produce its own wall chart. The bindings to
# "ins-self" are only displayed if there is an argument.
# If an argument is supplied, keys bound to "ins-self" will
# also be displayed.
def wallchart(f : Bool, n : Int32, k : Int32) : Result
  return Result::False unless makechart
  return b_to_r(Buffer.popsysbuf)
end

# Here we capture any unhandled exceptions, and print
# the exception information along with a backtrace before exiting.
begin
  e = E.new
  k = e.keymap
  k.add(Kbd.ctlx_ctrl('c'), cmdptr(quit), "quit")
  k.add(Kbd.ctrl('g'), cmdptr(ctrlg), "abort")
  k.add(Kbd.ctlx_ctrl('k'), cmdptr(wallchart), "display-bindings")
  k.add_dup('q', "quit")

  # Test of Ruby binding.  Ruby calls are not implemented yet, 
  # so these only display information on the echo line.
  k.addruby(Kbd.ctlx('d'), "insdate")
  k.addruby(Kbd.ctlx('x'), "xact")

  # The following bindings are for testing only!  Delete when
  # editor is fully implemented.
  k.add(Kbd.ctlx('e'), cmdptr(exception), "raise-exception")

  # Create some key bindings for other modules.
  Basic.bind_keys(k)
  Misc.bind_keys(k)
  Echo.bind_keys(k)
  Files.bind_keys(k)
  Window.bind_keys(k)
  Buffer.bind_keys(k)
  Word.bind_keys(k)
  Region.bind_keys(k)
  Search.bind_keys(k)
  Undo.bind_keys(k)
  RubyRPC.bind_keys(k)

  # Start the Ruby process
  Echo.puts("Unable to start Ruby server") unless RubyRPC.init_server

  # Load files specified on the command line.
  e.process_command_line

  # Enter the event loop, getting keys and responding to them.
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
