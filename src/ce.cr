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
require "./extend"
require "./macro"
require "./paragraph"
require "./e"

def quit(f : Bool, n : Int32, k : Int32) : Result
  # Check if there are any changed buffers.
  if Buffer.anycb
    return FALSE if Echo.yesno("There are changed buffers.  Quit") != TRUE
  end
  E.tty.close
  puts "Goodbye!"
  exit 0
  return TRUE
end

# Kills of any keyboard macro that is in progress.
def ctrlg(f : Bool, n : Int32, k : Int32) : Result
  # FIXME: end the macro here!
  return ABORT
end

def self.makechart
  # Populate the system buffer with the information about the
  # "normal" buffers.
  b = Buffer.sysbuf
  b.clear
  lines = [] of String
  E.keymap.k2n.each do |key, cmdname|
    if cmdname != "ins-self"
      keyname = Kbd.keyname(key).pad_right(16)
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
  return FALSE unless makechart
  return b_to_r(Buffer.popsysbuf)
end

# Starts recording a macro.
def ctlxlp(f : Bool, n : Int32, k : Int32) : Result
  if E.macro.recording?
    Echo.puts("Not now")
    return FALSE
  else
    Echo.puts("[Start macro]")
    E.macro.start_recording
    return TRUE
  end
end

# Stops recording a macro.
def ctlxrp(f : Bool, n : Int32, k : Int32) : Result
  if E.macro.recording?
    Echo.puts("[End macro]")
    E.macro.stop_recording
    return TRUE
  else
    Echo.puts("Not now")
    return FALSE
  end
end

# Executes the current (un-named) macro. The command argument is the
# number of times to loop. Quit as soon as a command gets an error.
# Returns TRUE if all ok, else FALSE.
def ctlxe(f : Bool, n : Int32, k : Int32) : Result
  # Can't do it if we're recording or already reading the macro.
  m = E.macro
  if m.recording? || m.reading?
    Echo.puts("Not now")
    return FALSE
  end

  # Read and execute the command for each key in the macro.  Stop if a
  # command returns a non-true result, or if we reach the end
  # of the macro.
  return TRUE if n <= 0

  # Run the macro n times.
  s = TRUE
  n.times do
    m.start_reading
    while true
      s = TRUE
      af = false
      an = 1
      c = m.read_int
      break unless c

      # Check for Ctrl-U numeric prefix.
      if c == Kbd.ctrl('u')
	af = true
	an = m.read_int
	break unless an
      end

      # If this key wasn't the end of of macro marker,
      # execute the command for this key.
      break if c == Kbd.ctlx(')')
      s = E.execute(c, af, an)
      break if s != TRUE
    end # while true

    break if s != TRUE
  end # n.times

  m.stop_reading
  return s
end

# Here we capture any unhandled exceptions, and print
# the exception information along with a backtrace before exiting.
begin
  e = E.new
  k = e.keymap
  k.add(Kbd.ctlx_ctrl('c'), cmdptr(quit), "quit")
  k.add(Kbd.ctrl('g'), cmdptr(ctrlg), "abort")
  k.add(Kbd.ctlx_ctrl('k'), cmdptr(wallchart), "display-bindings")
  k.add(Kbd.ctlx('('), cmdptr(ctlxlp), "start-macro")
  k.add(Kbd.ctlx(')'), cmdptr(ctlxrp), "end-macro")
  k.add(Kbd.ctlx('e'), cmdptr(ctlxe), "execute-macro")
  k.add_dup('q', "quit")

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
  Extend.bind_keys(k)
  Paragraph.bind_keys(k)

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
