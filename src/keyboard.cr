# Keys are represented using a 32-bit
# keyboard code, where bits 20-0 are the raw
# keycode, and bits 28-30 are modifier/prefix flags.
#
# +------+------+------+----+---------+
# |  30  |  29  |  28  | .. | 20 - 0  |
# +------+------+------+----+---------+
# | CTLX | META | CTRL | .. | KEYCODE |
# +------+------+------+----+---------+
#
#  KEYCODE - the "raw" key without any modifiers.  Values 0-127
#	     are ASCII, 128-255 are extended ASCII, and 256-511
#            are special keys like F1 or PGUP.
#  CTRL    - Control key or prefix (C-?)
#  META    - Alt key or ESC prefix (M-?)
#  CTLX    - Control-X prefix (C-X-?)
#
# Kbd.getkey returns this "cooked" representation.  For example,
# Ctrl-A would be returned as CTRL | 0x41, and Esc-A (M-A) would be returned
# as META | 0x41.
# 
# Kbd.getraw returns raw keycodes without prefix or modifier bits.
# So Ctrl-A would be returned as 0x01, and Esc-A would be returned
# as two successive keys, 0x1b and 0x41.

class Kbd

  # Prefix characters.
  METACH = 0x1B			# M- prefix,   Control-[, ESC
  CTMECH = 0x1C			# C-M- prefix, Control-\
  EXITCH = 0x1D			# Exit level,  Control-]
  CTRLCH = 0x1E			# C- prefix,   Control-^
  HELPCH = 0x1F			# Help key,    Control-_

  # Flags that are ORed with a keycode to indicate prefixes.
  CTRL = 0x10000000		# Control flag.
  META = 0x20000000		# Meta flag.
  CTLX = 0x40000000		# Control-X flag.

  # Mask for basic keycode.
  CHAR = 0x01FFFFF

  # Mask for ASCII code.
  ASCIIMASK = 0x7f

  # Our internal special key values.
  RANDOM = 0x80
  UP     = 0x81
  DOWN   = 0x82
  LEFT   = 0x83
  RIGHT  = 0x84
  PGUP   = 0x85
  PGDN   = 0x86
  HOME   = 0x87
  KEND   = 0x88
  INS    = 0x89
  DEL    = 0x8a
  F1     = 0x8b
  F2     = 0x8c
  F3     = 0x8d
  F4     = 0x8e
  F5     = 0x8f
  F6     = 0x90
  F7     = 0x91
  F8     = 0x92
  F9     = 0x93
  F10    = 0x94
  F11    = 0x95
  F12    = 0x96
  CLICK  = 0x97
  DCLICK = 0x98
  
  # Class methods.

  # Returns the internal value of the Ctrl-modified key *s*.
  # This is *not* the same as an ASCII control character;
  # for that, use `Terminal#ctrl`.
  def self.ctrl(s : Char) : Int32
    s.upcase.ord | CTRL
  end

  # Returns the internal value of the Meta-modified key *s*.
  def self.meta(s : Char) : Int32
    s.upcase.ord | META
  end

  # Returns the internal value of Meta-Ctrl-modified key *s*.
  def self.meta_ctrl(s : Char) : Int32
    s.upcase.ord | META | CTRL
  end

  # Returns the internal value of Ctrl-X *s" sequence.
  def self.ctlx(s : Char) : Int32
    s.upcase.ord | CTLX
  end

  # Returns the internal value of Ctrl-X Ctrl-*s" sequence.
  def self.ctlx_ctrl(s : Char) : Int32
    s.upcase.ord | CTLX | CTRL
  end

  # Returns a single-character string representing the ASCII-fied
  # version of a key.
  def self.ascii(k : Int32) : String
    # Get the unmodified key code.
    c = k & Kbd::CHAR;

    # ASCII-fy normal control characters, i.e., characters
    # Ctrl-@, Ctrl-A, Ctrl-B, etc., up to Ctrl-_.
    if (k & Kbd::CTRL) != 0 && c >= '@'.ord && c <= '_'.ord
      c -= '@'.ord
    end
    return c.chr.to_s
  end

  # Names of our special keys, plus a few others in the normal ASCII range.
  @@keynames = {
     # Special keys
     UP    => "Up",
     DOWN  => "Down",
     LEFT  => "Left",
     RIGHT => "Right",
     PGUP  => "Pgup",
     PGDN  => "Pgdn",
     HOME  => "Home",
     KEND  => "Kend",
     INS   => "Ins",
     DEL   => "Del",
     F1    => "F1",
     F2    => "F2",
     F3    => "F3",
     F4    => "F4",
     F5    => "F5",
     F6    => "F6",
     F7    => "F7",
     F8    => "F8",
     F9    => "F9",
     F10   => "F10",
     F11   => "F11",
     F12   => "F12",

     # ASCII keys.
     ctrl('i') => "Tab",
     ctrl('m') => "Return",
     ctrl('h') => "Backspace",
     0x20      => "Space",
     0x7f      => "Rubout"
  }

  # Return the string representation of a keycode.
  def self.keyname(k : Int32) : String
    k ||= '?'.ord

    # Negative numbers are special, and are used for unbound commands.
    if k < 0
      return "Unbound-#{-k}"
    end

    # If it's an ASCII control character, output ^C, where
    # is the corresponding letter.
    if k >= 0x00 && k <= 0x1a
      return "^" + (k + '@'.ord).chr.to_s
    end

    # Check for Ctrl-X and Meta prefixes.
    s = String.build do |s|
      s << ""
      s << "C-X " if (k & CTLX) == CTLX
      s << "M-" if (k & META) == META
      k &= ~(CTLX | META)

      # Is the keycode in the special keys table?
      n = @@keynames[k]?
      if n
	# Output the special key name.
	s << n
      else
	# Check for Ctrl modifier.
	s << "C-" if (k & CTRL) == CTRL

	# Look it up again in the table, but this time without CTRL.
	n = @@keynames[k & CHAR]?
	if n
	  s << n
	else
	  # Not in table, output the ASCII character.
	  s << String.new(Bytes[k & ASCIIMASK])
	end
      end
    end
    return s
  end

  def initialize(tty : Terminal)
    # Set the associated Terminal object
    @tty = tty

    # Precompute some useful ASCII control character constants.
    @ctrl_x =  tty.ctrl('x')
    @ctrl_at = tty.ctrl('@')
    @ctrl_z =  tty.ctrl('z')
  end

  # Get the raw keycode from the Terminal, or from the
  # profile file if one is currently active.
  def getinp
    @tty.getc
  end

  # Helper function for getkey; shouldn't be called outside this module.
  # Gets a key after a prefix has been seen; converts lower to upper, and
  # converts control characters to our internal representation.
  def getctrl : Int32
    c = getinp
    case c
    when ('a'.ord..'z'.ord)	# convert to upper case
      return c - 'a'.ord + 'A'.ord 
    when (@ctrl_at..@ctrl_z)   # control key
      return CTRL | (c + '@'.ord)
    else
      return c
    end
  end

  # Get a "cooked" key, in our internal representation.
  def getkey : Int32
    c = getinp
    case c
    when METACH
      return META | getctrl
    when CTMECH
      return CTRL | META | getctrl
    when CTRLCH
      return CTRL | getctrl
    when @ctrl_x
      return CTLX | getctrl
    when (@ctrl_at..@ctrl_z)
      return CTRL | (c + '@'.ord)
    else
      return c
    end
  end

end
