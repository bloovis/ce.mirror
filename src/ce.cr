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

@[Flags]
enum Eflags
  Cpcn		# last command was C-P or C-N
  Kill		# last command was a kill
end

# `E` a singleton class that implements the top-level editor code,
# including the initialization and event loop.  It also provides
# access to "global" psuedo-variables such as `curw` (the current window)
# and `curb` (the current buffer).
class E
  @@instance : E?
  @@lastflag : Eflags = Eflags::None
  @@thisflag : Eflags = Eflags::None

  property tty : Terminal
  property keymap : KeyMap
  property kbd : Kbd
  property disp : Display

  # Use the following class methods to access the instance variables
  # of the single instance of `E1.

  # Returns the single instance of E
  private def self.instance : E
    inst = @@instance
    if inst
      return inst
    else
      raise "E not instantiated!"
    end
  end

  # Returns the current window.
  def self.curw : Window
    Window.current
  end

  # Sets the current window.
  def self.curw=(w : Window)
    Window.current = w
  end

  # Returns the current buffer, i.e., the buffer associated with
  # the current window.
  def self.curb : Buffer
    Window.current.buffer
  end

  # Returns the current buffer list.
  def self.buffers : Array(Buffer)
    Buffer.buffers
  end

  # Returns the Terminal object.
  def self.tty : Terminal
    t = self.instance.tty
    if t
      return t
    else
      raise "No Terminal object!"
    end
  end

  def self.lastflag : Eflags
    return @@lastflag
  end

  def self.thisflag
    return @@thisflag
  end

  def self.thisflag=(f : Eflags)
    @@thisflag = f
  end

  # Returns the context of dot as a tuple containing
  # the current window, buffer, dot, and line pointer.
  def self.get_context : Tuple(Window, Buffer, Pos, Pointer(Line))
    w = E.curw
    b = w.buffer
    dot = w.dot
    lp = b[dot.l]
    raise "Nil line in get_context!" if lp.nil?
    return {w, b, dot, lp}
  end

  def initialize
    # Create a terminal object.
    @tty = Terminal.new
    @tty.open

    # Create a keyboard object.
    @kbd = Kbd.new(@tty)

    # Create some key bindings for this module.
    @keymap = KeyMap.new
    @keymap.add(Kbd.ctlx_ctrl('c'), cmdptr(quit), "quit")
    @keymap.add_dup('q', "quit")
    @keymap.add('c', cmdptr(change), "toggle-changed-flag")
    @keymap.add('e', cmdptr(exception), "raise-exception")

    # Create some key bindings for other modules.
    Basic.bind_keys(@keymap)
    Misc.bind_keys(@keymap)

    # Create a display object.
    @disp = Display.new(@tty)

    # Set some flags.
    @@lastflag = Eflags::None
    @@thisflag = Eflags::None

    # Set the instance to make this a pseudo-singleton class.
    @@instance = self
  end

  # Reads options and filenames from the command line, reads each file
  # into its own buffer, creates windows for as many buffers as can fit
  # on the screen.
  def process_command_line
    # Create a buffer, and read the file specified on the command line,
    # or just leave the buffer empty if no file was specified.
    if ARGV.size == 0
      b = Buffer.new("main")
    else
      ARGV.each do |filename|
        b = Buffer.new(filename)
        b.readfile(filename)
      end
    end

    # Arbitrarily assume the smallest window we will allow is five lines, plus
    # the status line.  Calculate how many such windows will fit on the screen,
    # and how big each window will be.
    nwin = (@tty.nrow - 1) // 6
    if nwin > E.buffers.size
      nwin = E.buffers.size
    end
    nrow = ((@tty.nrow - 1) // nwin) - 1

    # Create up to `nwin` windows for the buffers we've read.
    toprow = 0
    nwin.times do |i|
      b = E.buffers[i]
      w = Window.new(b)
      E.curw = w if i == 0
      w.toprow = toprow
      if i == nwin - 1
	w.nrow = @tty.nrow - toprow - 2
      else
	w.nrow = nrow
      end
      toprow += nrow + 1
    end
  end

  # Enters a loop waiting for the user to hit a key, and responds by executing
  # the command bound to that key.
  def event_loop
    # Repeatedly get keys, perform some actions.
    # Most keys skip to the next page, PGUP skips
    # the previous page, q quits.
    done = false
    ctrlu = Kbd.ctrl('u')
    zero = '0'.ord
    nine = '9'.ord
    minus = '-'.ord

    while !done
      @disp.update
      c = @kbd.getkey
      Echo.erase

      # Handle the CTRL-U + digits prefix.
      f = false
      n = 1
      if c == ctrlu
	f = true
	n = 4
	while (c = @kbd.getkey) == ctrlu
	  n *= 4
	  if (c >= zero && c <= nine) || c == minus
	    if c == minus
	      n = 0
	      mflag = true
	    else
	      n = c - zero
	      mflag = false
	    end
	    while (c = @kbd.getkey) >= zero && c <= nine
	      n = (10 * n) + (c - zero)
	    end
	    if mflag
	      n = (n == 0 ? -1 : -n)
	    end
	  end
	end
      end

      # Call the function bound to the key.
      if @keymap.key_bound?(c)
	@@thisflag = Eflags::None
        @keymap.call_by_key(c, f, n)
	@@lastflag = @@thisflag
      else
	@tty.move(E.tty.nrow-1, 0)
	@tty.puts("key #{@kbd.keyname(c)} not bound!")
	@tty.eeol
      end

    end

    # Close the terminal.
    @tty.close
  end

end

# Here we capture any unhandled exceptions, and print
# the exception information along with a backtrace before exiting.
begin
  e = E.new
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
