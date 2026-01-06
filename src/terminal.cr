require "./curses"
require "./keyboard"

# `Terminal` provides an abstraction layer over Ncurses, for writing
# to the screen and accepting keyboard input.
class Terminal
  # Number of rows and columns in this terminal.
  property nrow : Int32
  property ncol : Int32

  # Current row and column of cursor.
  property row : Int32
  property col : Int32

  # Handle to the Ncurses window.
  property scr : LibNCurses::Window

  # Colors
  CNONE = 0
  CTEXT = 1
  CMODE = 2

  # Map Ncurses special key values to our own internal key values.
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

  # Initialize our instance variables but don't initialize ncurses yet.
  def initialize
    @scr = LibNCurses.initscr
    @npages = 1
    @nrow = -1
    @ncol = -1
    @row = -1
    @col = -1
  end

  # Initialize the display and keyboard.
  def open
    # Ncurses.cbreak           # provide unbuffered input
    LibNCurses.noecho           # turn off input echoing
    LibNCurses.raw		     # don't let Ctrl-C generate a signal
    LibNCurses.nonl             # turn off newline translation
    #LibNCurses.stdscr.intrflush(false) # turn off flush-on-interrupt
    LibNCurses.keypad(@scr, true)     # turn on keypad mode

    # Get number of rows and columns.
    getsize
  end

  # Restore the display and keyboard to their original, pre-open state.
  def close
    LibNCurses.echo
    LibNCurses.nocbreak
    LibNCurses.nl
    LibNCurses.endwin
  end

  # Save the current terminal size in nrow and ncol.
  def getsize
    @nrow = LibNCurses.getmaxy(@scr)
    @ncol = LibNCurses.getmaxx(@scr)
  end

  # Move the cursor.
  def move(row : Int32, col : Int32)
    LibNCurses.wmove(@scr, row, col)
    @row = row
    @col = col
  end

  # Erase to end of line.
  def eeol
    LibNCurses.wclrtoeol(@scr)
  end

  # Erase to end of screen.
  def eeop
    LibNCurses.wclrtobot(@scr)
  end

  # Set the color.  There are two possibilities:
  #   - CTEXT for normal color
  #   - CMODE for inverted video used on the mode line
  def color(color)
    LibNCurses.wbkgdset(@scr, ' '.ord | (color == CMODE ?
					    LibNCurses::A_REVERSE :
					    LibNCurses::A_NORMAL))
  end

  # Refresh the display after a terminal resize.
  def resize
    initialize
    getsize
    LibNCurses.wrefresh(@scr)
  end

  # Write a character to the screen.
  def putc(c : Char)
    LibNCurses.waddch(@scr, c.ord)
  end

  # Write a string to the screen, but don't erase to end of line afterwards.
  def puts(s : String)
    LibNCurses.waddstr(@scr, s)
  end

  # Write a string to the screen, then erase to the end of the line.
  def putline(row  : Int32, col : Int32, s : String)
    move(row, col)
    puts(s)
    eeol
  end

  # Make the physical screen match the virtual screen.
  def flush
    LibNCurses.wrefresh(@scr)
  end

  # Read a character from the keyboard with little processing,
  # besides converting special functions keys to our own representation.
  # The Kbd module cooks the characters more by handling prefixes.
  def getc : Int32
    while LibNCurses.wget_wch(@scr, out c) == LibNCurses::ERR
    end

    case c
    when (0..255)
      # Return normal key.
      return c
    when LibNCurses::KEY_BACKSPACE
      # Treat backspace as Ctrl-H.
      return ctrl('h')
    when LibNCurses::KEY_RESIZE
      # Treat window resize as Ctrl-L, which will force a screen redraw.
      return ctrl('l')
    when LibNCurses::KEY_MOUSE
      return 'x'.ord		# horrible testing hack!!!
    else
      # Try special key map key.
      @@keymap[c] || Kbd::RANDOM
    end
  end

  # Return the ASCII value of a Ctrl-modified key.
  def ctrl(c : Char) : Int32
    return c.ord & 0x1f
  end

end
