require "./ll"
require "./line"
require "./buffer"
require "./window"
require "./keyboard"
require "./terminal"
require "./keymap"
require "./display"

def back_page(f : Bool, n : Int32, k : Int32) : Result
  E.curw.line -= E.curw.nrows
  E.curw.line = 0 if E.curw.line < 0
  return Result::True
end

def forw_page(f : Bool, n : Int32, k : Int32) : Result
  E.curw.line += E.curw.nrows
  return Result::True
end

def change(f : Bool, n : Int32, k : Int32) : Result
  E.curb.flags = E.curb.flags ^ Bflags::Changed
  return Result::True
end

def quit(f : Bool, n : Int32, k : Int32) : Result
  E.tty.close
  puts "Goodbye!"
  exit 0
  return Result::True
end

# `E` a singleton class that implements the top-level editor code,
# including the initialization and event loop.  It also provides
# access to "global" psuedo-variables such as `curw` (the current window)
# and `curb` (the current buffer).
class E
  @@instance : E?

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

  def initialize
    # Create a terminal object.
    @tty = Terminal.new
    @tty.open

    # Create a keyboard object.
    @kbd = Kbd.new(@tty)

    # Create some key bindings.
    @keymap = KeyMap.new
    @keymap.add(Kbd::PGDN, cmdptr(forw_page), "down-page")
    @keymap.add(Kbd::PGUP, cmdptr(back_page), "up-page")
    @keymap.add(Kbd.ctlx_ctrl('c'), cmdptr(quit), "quit")
    @keymap.add_dup('q', "quit")
    @keymap.add('c', cmdptr(change), "toggle-changed-flag")

    # Create a display object.
    @disp = Display.new(@tty)

    # Set the instance to make this a pseudo-singleton class.
    @@instance = self
  end

  # Reads options and filenames from the command line, reads each file
  # into its own buffer, creates windows for as many buffers as can fit
  # on the screen.
  def process_command_line
    # Create a buffer, and read the file specified on the command line,
    # or just leave the buffer empty if no file was specified.
    if ARGV.size > 0
      filename = ARGV[0]
      b = Buffer.new(filename)
      b.readfile(filename)
    else
      b = Buffer.new("main")
    end
    #puts "There are #{b.length} lines in the buffer"

    # Create a window on the buffer that fills the screen.
    w = Window.new(b)
    E.curw = w
    E.curw.toprow = 0
    E.curw.nrows = @tty.nrow - 2
    if b != E.curb
      raise "Current buffer #{E.curb} is not #{b}!"
    end
  end

  # Enters a loop waiting for the user to hit a key, and responds by executing
  # the command bound to that key.
  def event_loop
    # Repeatedly get keys, perform some actions.
    # Most keys skip to the next page, PGUP skips
    # the previous page, q quits.
    c = 'x'.ord
    done = false
    while !done
      @disp.update
      @tty.move(@tty.nrow-1, 0)
      c = @kbd.getkey

      if @keymap.key_bound?(c)
        @tty.puts(sprintf("last key hit: %#x (%s), at line %d: Hit any key:",
		  [c, @kbd.keyname(c), E.curw.line]))
        @keymap.call_by_key(c, false, 42)
      else
        @tty.puts(sprintf("last key hit: %#x (%s)(undef), at line %d: Hit any key:",
		  [c, @kbd.keyname(c), E.curw.line]))
      end
      @tty.eeol
    end

    # Close the terminal.
    @tty.close
  end

end

e = E.new
e.process_command_line
e.event_loop
