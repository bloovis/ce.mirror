require "./ll"
require "./line"
require "./buffer"
require "./window"
require "./keyboard"
require "./terminal"
require "./keymap"
require "./display"

class Editor
  @@buffers = [] of Buffer

  property tty : Terminal
  property w : Window
  property k : KeyMap

  def back_page(f : Bool, n : Int32, k : Int32) : Result
    @w.line -= @w.nrows
    @w.line = 0 if @w.line < 0
    return Result::True
  end

  def forw_page(f : Bool, n : Int32, k : Int32) : Result
    @w.line += @w.nrows
    return Result::True
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
    @kbd = Kbd.new(@tty)

    # Create a buffer and read the file "junk" into it.
    @b = Buffer.new("junk")
    @b.readfile("junk")
    #puts "There are #{@b.length} lines in the buffer"

    # Create a window on the buffer that fills the screen.
    @w = Window.new(@b)
    @w.toprow = 0
    @w.nrows = @tty.nrow - 2

    # Update the display.
    @disp = Display.new(@tty)

    # Creating some key bindings.
    @k = KeyMap.new
    @k.add(Kbd::PGDN, cmdptr(forw_page), "down-page")
    @k.add(Kbd::PGUP, cmdptr(back_page), "up-page")

    # Repeatedly get keys, perform some actions.
    # Most keys skip to the next page, PGUP skips
    # the previous page, q quits.
    @keys = [] of Int32
    c = 'x'.ord
    done = false
    while !done
      @disp.update
      c = @kbd.getkey
      @keys << c

      @tty.move(@tty.nrow-1, 0)
      if @k.key_bound?(c)
        @tty.puts(sprintf("last key hit: %#x (%s), at line %d: Hit any key:",
		  [c, @kbd.keyname(c), @w.line]))
        @k.call_by_key(c, false, 42)
      else
        @tty.puts(sprintf("last key hit: %#x (%s)(undef), at line %d: Hit any key:",
		  [c, @kbd.keyname(c), @w.line]))
      end
      @tty.eeol

      case c
      when Kbd.ctrl('c'), 'Q'.ord, 'q'.ord
	done = true
#      when Kbd::PGUP
#	@w.line -= @w.nrows
#	@w.line = 0 if @w.line < 0
#      else
#	@w.line += @w.nrows
      end

      if @w.line >= @b.length
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

e = Editor.new
#E.main
