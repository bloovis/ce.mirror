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

# `E` a singleton class that implements the top-level editor code,
# including the initialization and event loop.  It also provides
# access to "global" variable such as curw (the current window).
class E
  @@instance : E?

  property buffers = [] of Buffer
  property tty : Terminal
  property curw : Window
  property keymap : KeyMap

  def self.instance : E
    inst = @@instance
    if inst
      return inst
    else
      raise "E not instantiated!"
    end
  end

  # Returns the current window.
  def self.curw
    self.instance.curw
  end

  def initialize
    # Create a terminal object; clear screen and write the last two lines.
    @tty = Terminal.new
    @tty.open
    @tty.move(@tty.nrow - 2, 0)
    @tty.color(Terminal::CMODE)
    @tty.eeol
    @tty.puts("*MicroEMACS test.rb File:test.rb")
    @tty.color(Terminal::CTEXT)

    # Create a keyboard object.
    @keymapbd = Kbd.new(@tty)

    # Create a buffer and read the file "junk" into it.
    @b = Buffer.new("junk")
    @b.readfile("junk")
    #puts "There are #{@b.length} lines in the buffer"

    # Create a window on the buffer that fills the screen.
    @curw = Window.new(@b)
    @curw.toprow = 0
    @curw.nrows = @tty.nrow - 2

    # Update the display.
    @disp = Display.new(@tty)

    # Creating some key bindings.
    @keymap = KeyMap.new
    @keymap.add(Kbd::PGDN, cmdptr(forw_page), "down-page")
    @keymap.add(Kbd::PGUP, cmdptr(back_page), "up-page")

    # Set the instance to make this a pseudo-singleton class.
    @@instance = self
  end

  def event_loop
    # Repeatedly get keys, perform some actions.
    # Most keys skip to the next page, PGUP skips
    # the previous page, q quits.
    c = 'x'.ord
    done = false
    while !done
      @disp.update
      @tty.move(@tty.nrow-1, 0)
      c = @keymapbd.getkey

      if @keymap.key_bound?(c)
        @tty.puts(sprintf("last key hit: %#x (%s), at line %d: Hit any key:",
		  [c, @keymapbd.keyname(c), @curw.line]))
        @keymap.call_by_key(c, false, 42)
      else
        @tty.puts(sprintf("last key hit: %#x (%s)(undef), at line %d: Hit any key:",
		  [c, @keymapbd.keyname(c), @curw.line]))
      end
      @tty.eeol

      case c
      when Kbd.ctrl('c'), 'Q'.ord, 'q'.ord
	done = true
#      when Kbd::PGUP
#	@curw.line -= @curw.nrows
#	@curw.line = 0 if @curw.line < 0
#      else
#	@curw.line += @curw.nrows
      end

      if @curw.line >= @b.length
	done = true
      end
    end

    # Close the terminal.
    @tty.close
  end
    
  def readfiles
    ARGV.each do |arg|
      filename = arg
      b = Buffer.new(filename)
      @@buffers << b
      if b.readfile(filename)
	puts "Successfully read #{filename}:"
      else
	puts "Couldn't read #{filename}"
      end
      lineno = 1
      b.each do |s|
	puts "#{lineno}: #{s.text}"
	lineno += 1
      end
    end
  end

end

e = E.new
e.event_loop
#E.main
