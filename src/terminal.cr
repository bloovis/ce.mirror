require "./curses"
require "./keyboard"


# We have to set the locale so that ncurses will work correctly
# with UTF-8 string.
lib Locale
  # LC_CTYPE is probably 0 (at least in glibc)
  LC_CTYPE = 0
  fun setlocale(category : Int32, locale : LibC::Char*) : LibC::Char*
end

# `Terminal` provides an abstraction layer over ncurses, for writing
# to the screen and accepting keyboard input.
class Terminal
  # Number of rows in this terminal.
  property nrow : Int32

  # Number of columns in this terminal.
  property ncol : Int32

  # Current row of cursor.
  property row : Int32

  # Current column of cursor.
  property col : Int32

  # Handle to the ncurses window.
  property scr : LibNCurses::Window

  # No color.
  CNONE = 0

  # Color of normal text.
  CTEXT = 1

  # Color of mode line.
  CMODE = 2

  # Map ncurses special key values to our own internal key values.
  @@keymap = {
     LibNCurses::KEY_UP => Kbd::UP,
     LibNCurses::KEY_DOWN => Kbd::DOWN,
     LibNCurses::KEY_LEFT => Kbd::LEFT,
     LibNCurses::KEY_RIGHT => Kbd::RIGHT,
     LibNCurses::KEY_PPAGE => Kbd::PGUP,
     LibNCurses::KEY_NPAGE  => Kbd::PGDN,
     LibNCurses::KEY_HOME => Kbd::HOME,
     LibNCurses::KEY_END => Kbd::KEND,
     LibNCurses::KEY_IC => Kbd::INS,
     LibNCurses::KEY_DC => Kbd::DEL,
     LibNCurses::KEY_F1 => Kbd::F1,
     LibNCurses::KEY_F2 => Kbd::F2,
     LibNCurses::KEY_F3 => Kbd::F3,
     LibNCurses::KEY_F4 => Kbd::F4,
     LibNCurses::KEY_F5 => Kbd::F5,
     LibNCurses::KEY_F6 => Kbd::F6,
     LibNCurses::KEY_F7 => Kbd::F7,
     LibNCurses::KEY_F8 => Kbd::F8,
     LibNCurses::KEY_F9 => Kbd::F9,
     LibNCurses::KEY_F10 => Kbd::F10,
     LibNCurses::KEY_F11 => Kbd::F11,
     LibNCurses::KEY_F12 => Kbd::F12
  }

  # Initializse our instance variables but doesn't initialize ncurses yet.
  def initialize
    Locale.setlocale(Locale::LC_CTYPE, "")
    @scr = LibNCurses.initscr
    @npages = 1
    @nrow = -1
    @ncol = -1
    @row = -1
    @col = -1
  end

  # Initializes the display and the keyboard using ncurses.
  def open
    LibNCurses.keypad(@scr, true)     # turn on keypad mode
    LibNCurses.nonl             # turn off newline translation
    LibNCurses.cbreak           # provide unbuffered input
    LibNCurses.noecho           # turn off input echoing
    LibNCurses.raw		# don't let Ctrl-C generate a signal
    #LibNCurses.stdscr.intrflush(false) # turn off flush-on-interrupt

    # Get number of rows and columns.
    getsize
  end

  # Restores the display and keyboard to their original, pre-open state.
  def close
    LibNCurses.echo
    LibNCurses.nocbreak
    LibNCurses.nl
    LibNCurses.endwin
  end

  # Saves the current terminal size in `@nrow` and `@ncol`.
  def getsize
    @nrow = LibNCurses.getmaxy(@scr)
    @ncol = LibNCurses.getmaxx(@scr)
  end

  # Moves the cursor to the location *row* and *column* (zero-based).
  def move(row : Int32, col : Int32)
    LibNCurses.wmove(@scr, row, col)
    @row = row
    @col = col
  end

  # Erases to end of line.
  def eeol
    LibNCurses.wclrtoeol(@scr)
  end

  # Erases to end of screen.
  def eeop
    LibNCurses.wclrtobot(@scr)
  end

  # Set the color.  There are two possibilities:
  # * `CTEXT` for normal color
  # * `CMODE` for inverted video used on the mode line
  def color(color)
    LibNCurses.wbkgdset(@scr, ' '.ord | (color == CMODE ?
					    LibNCurses::A_REVERSE :
					    LibNCurses::A_NORMAL))
  end

  # Refreshes the display after a terminal resize.
  def resize
    initialize
    getsize
    LibNCurses.wrefresh(LibNCurses.curscr)
  end

  # Writes a character to the screen at the current location.
  def putc(c : Char)
    LibNCurses.waddstr(@scr, c.to_s)
  end

  # Writes a string to the screen at the current location, but don't erase to
  # end of line afterwards.
  def puts(s : String)
    LibNCurses.waddstr(@scr, s)
  end

  # Writes a string to the screen at the location *row* and *column*
  # (zero-based), then erases to the end of the line.
  def putline(row  : Int32, col : Int32, s : String)
    move(row, col)
    puts(s)
    eeol
  end

  # Makes the physical screen match the virtual screen in ncurses.
  def flush
    LibNCurses.wrefresh(@scr)
  end

  # Reads a character from the keyboard with little processing,
  # besides converting special functions keys to our own representation.
  # The `Kbd` module cooks the characters more by handling prefixes.
  def getc : Int32
    while (result = LibNCurses.wget_wch(@scr, out c)) == LibNCurses::ERR
    end

    #STDERR.puts "gets: c #{c}, result #{result}"
    if result == LibNCurses::KEY_CODE_YES
      case c
      when LibNCurses::KEY_BACKSPACE
	# Treat backspace as Ctrl-H.
	return ctrl('h')
      when LibNCurses::KEY_RESIZE
	return ctrl('l')		# Ctrl-L will force a screen redraw
      when LibNCurses::KEY_MOUSE
	return Kbd::CLICK		# Horrible hack for mouse
      else
	if special = @@keymap[c]?	# Try special key map
	  return special
	else
	  return Kbd::RANDOM		# Unknown function key
	end
      end
    else
      return c.chr.ord			# Unicode codepoint
    end
  end

  # Returns the ASCII value of a Ctrl-modified key.
  def ctrl(c : Char) : Int32
    return c.ord & 0x1f
  end

end
