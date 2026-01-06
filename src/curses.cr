# This is a stripped-down version of the ncurses shard (github SamualLB/ncurses),
# with just enough functionality to support the editor.

@[Link("ncursesw")]
lib LibNCurses
  alias Wint_t = Int32
  type Window = Void*

  # (w)get_wch error value.
  ERR = -1

  # Background values
  A_NORMAL = 0x0
  A_REVERSE = 0x40000

  # Keys
  KEY_CANCEL = 0x163
  KEY_CODE_YES = 0x100
  KEY_MOUSE = 0x199
  KEY_ENTER = 0x157
  KEY_BACKSPACE = 0x107
  KEY_UP = 0x103
  KEY_DOWN = 0x102
  KEY_LEFT = 0x104
  KEY_RIGHT = 0x105
  KEY_PPAGE = 0x153
  KEY_NPAGE = 0x152
  KEY_HOME = 0x106
  KEY_END = 0x168
  KEY_IC = 0x14b
  KEY_DC = 0x14a
  KEY_F1 = 0x109
  KEY_F2 = 0x10a
  KEY_F3 = 0x10b
  KEY_F4 = 0x10c
  KEY_F5 = 0x10d
  KEY_F6 = 0x10e
  KEY_F7 = 0x10f
  KEY_F8 = 0x110
  KEY_F9 = 0x111
  KEY_F10 = 0x112
  KEY_F11 = 0x113
  KEY_F12 = 0x114
  KEY_F13 = 0x115
  KEY_F14 = 0x116
  KEY_F15 = 0x117
  KEY_F16 = 0x118
  KEY_F17 = 0x119
  KEY_F18 = 0x11a
  KEY_F19 = 0x11b
  KEY_F20 = 0x11c
  KEY_RESIZE = 0x19a

  # General functions
  fun initscr : Window
  fun endwin : LibC::Int

  # General window functions
  fun getmaxy(window : Window) : LibC::Int
  fun getmaxx(window : Window) : LibC::Int
  fun wmove(window : Window, row : LibC::Int, col : LibC::Int) : LibC::Int
  fun wrefresh(window : Window) : LibC::Int
  fun wclrtoeol(window : Window) : LibC::Int
  fun wclrtobot(window : Window) : LibC::Int

  # Input option functions
  fun cbreak : LibC::Int
  fun nocbreak : LibC::Int
  fun echo : LibC::Int
  fun noecho : LibC::Int
  fun raw : LibC::Int

  # Window input option function
  fun keypad(window : Window, value : Bool)

  # Input functions
  fun wget_wch(window : Window, ch : Wint_t*) : LibC::Int
  fun get_wch(Wint_t*) : LibC::Int

  # Window background functions
  fun wbkgdset(window : Window, char : LibC::UInt)

  # Window output
  fun waddstr(window : Window, str : LibC::Char*) : LibC::Int
  fun waddch(window : Window, chr : LibC::Char)

  # Output options
  fun nl : LibC::Int
  fun nonl : LibC::Int
end

# We have to set the locale so that Ncurses will work correctly
# with UTF-8 string.

lib Locale
  # LC_CTYPE is probably 0 (at least in glibc)
  LC_CTYPE = 0
  fun setlocale(category : Int32, locale : LibC::Char*) : LibC::Char*
end

Locale.setlocale(Locale::LC_CTYPE, "")
