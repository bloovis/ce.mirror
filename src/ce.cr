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
require "./spell"
require "./config"
require "./e"
require "../version"

# Setting DEBUG to true enables logging, i.e. all calls to E.log
# will send output to the file ce.log .
DEBUG = false

# This command exits the editor.  If there are changed buffers,
# it prompts the user for confirmation.
def quit(f : Bool, n : Int32, k : Int32) : Result
  # Check if there are any changed buffers.
  if Buffer.anycb
    return FALSE if Echo.yesno("There are changed buffers.  Quit") != TRUE
  end
  E.tty.close
  exit 0
  return TRUE
end

# This command kills off any keyboard macro recording that is in progress.
# It is also a general purpose abort method that can be called
# from other commands.
def ctrlg(f : Bool, n : Int32, k : Int32) : Result
  E.macro.stop_recording
  return ABORT
end

# Populates the system buffer with the information about all buffers.
def makechart
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

# This command creates a table, listing all
# of the command keys and their current bindings, and stores
# the table in the system pop-op buffer. This
# lets the editor produce its own wall chart.
def wallchart(f : Bool, n : Int32, k : Int32) : Result
  return FALSE unless makechart
  return b_to_r(Buffer.popsysbuf)
end

# This command starts recording a macro.
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

# This command stops recording a macro.
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

# Adds process information for the process *pid* to the system buffer *b*,
# using *name* as the name of the process.
def process_info(b : Buffer, pid : Int64, name : String)
  begin
    s = File.read("/proc/#{pid}/statm")
    vals = s.split
    b.addline("")
    header = "#{name} (pid #{pid}) process information"
    b.addline(header)
    b.addline("=" * header.size)
    b.addline("All values in pages)")
    b.addline("Total program size:   #{vals[0]}")
    b.addline("Resident set size:    #{vals[1]}")
    b.addline("Resident shared size: #{vals[2]}")
    b.addline("Code size:            #{vals[3]}")
    b.addline("Data + stack size:    #{vals[5]}")
  rescue
    b.addline("Unable to obtain information for #{name} process")
  end
end

# This command reports on some internal statistics, and
# process information for the editor and the Ruby server.
def stats(f : Bool, n : Int32, k : Int32) : Result
  curb = E.curb
  b = Buffer.sysbuf
  b.clear

  # Display some stats from ce itself.
  b.addline("Editor information")
  b.addline("==================")
  b.addline("Current buffer line cache size:   #{curb.lcache.size}")
  nsent, nreceived, bytes_sent, bytes_received = RubyRPC.stats
  b.addline("JSON messages sent to Ruby:       #{nsent}")
  b.addline("JSON messages received from Ruby: #{nreceived}")
  b.addline("Bytes sent to Ruby:               #{bytes_sent}")
  b.addline("Bytes received from Ruby:         #{bytes_received}")

  # Display process info for editor.
  process_info(b, Process.pid, "ce")

  # Display process info for Ruby.
  pid = RubyRPC.pid
  if pid != 0
    process_info(b, pid, "ruby")
  end
  return b_to_r(Buffer.popsysbuf)
end

# This command executes the current (un-named) macro. The command argument is the
# number of times to loop. Quits as soon as a command gets an error.
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

# This command displays the version of ce on the echo line.
def showversion(f : Bool, n : Int32, k : Int32) : Result
  Echo.puts("CrystalEdit version #{VERSION}")
  return TRUE
end

# The main program of the editor. We capture any unhandled exceptions, and print
# the exception information along with a backtrace before exiting.
begin
  # Create the main editor object.
  e = E.new

  # If DEBUG is true, create the log file.
  E.open_log("ce.log") if DEBUG

  # Create the keymap and add our commands to it.
  k = e.keymap
  k.add(Kbd.ctlx_ctrl('c'), cmdptr(quit), "quit")
  k.add(Kbd.ctrl('g'), cmdptr(ctrlg), "abort")
  k.add(Kbd.ctlx_ctrl('k'), cmdptr(wallchart), "display-bindings")
  k.add(Kbd.ctlx('('), cmdptr(ctlxlp), "start-macro")
  k.add(Kbd.ctlx(')'), cmdptr(ctlxrp), "end-macro")
  k.add(Kbd.ctlx('e'), cmdptr(ctlxe), "execute-macro")
  k.add(Kbd.ctlx('v'), cmdptr(showversion), "display-version")
  k.add(Kbd::RANDOM, cmdptr(stats), "display-stats")
  k.add_dup(Kbd::F4, "quit")

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
  Spell.bind_keys(k)

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
