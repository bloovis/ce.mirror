# The `Misc` module contains some commands for inserting and deleting text.
module Misc

  extend self

  # Returns the current column position of dot, taking into account tabs
  # and control characters.
  def getcolpos : Int32
    w, b, dot, lp = E.get_context
    return Display.screen_size(lp.text, dot.o)
  end

  # Shows information about the dot: the character, the line number,
  # the screen row, the column, how far the dot is in the buffer
  # as a percentage, and the total bytes in the buffer.
  def showcpos(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context
    nlines = 0
    bytes = 0
    bytes_at_dot = 0
    b.each_line do |n,l|
      nlines += 1
      if l == lp
	bytes_at_dot = bytes + dot.o
      end
      bytes += l.text.size + 1
      true # tell each_line to continue
    end
    bytes -= 1	# adjust for last line
    if bytes == 0
      percent = 0
    else
      percent = bytes_at_dot * 100 // bytes
    end
    text = lp.text
    lsize = text.size
    if dot.o >= lsize
      c = 0x0a
    else
      c = lp.text[dot.o].ord
    end
    s = sprintf("[CH:0x%02X Line:%d Row:%d Col:%d %d%% of %d]",
	[c, dot.l + 1, dot.l - w.line + w.toprow + 1, dot.o + 1,
	 percent, bytes])
    Echo.puts(s)
    return Result::True
  end

  # Inserts *n* copies of the key *k* at the current location.
  def selfinsert(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::True if n == 0

    # Get the unmodified key code.
    c = k & Kbd::CHAR;

    # ASCII-fy normal control characters, i.e., characters
    # Ctrl-@, Ctrl-A, Ctrl-B, etc., up to Ctrl-_.
    if (k & Kbd::CTRL) != 0 && c >= '@'.ord && c <= '_'.ord
      c -= '@'.ord
    end

    # Insert *n* copies of the character.
    Line.insert(c.chr.to_s * n)
    return Result::True
  end

  # Opens up some blank space by inserting one or more newlines
  # and then backing up over them.
  def openline(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::True if n == 0

    n.times {Line.newline}
    return Basic.backchar(f, n, Kbd::RANDOM)
  end

  # Inserts *n* newlines at the current location.
  def insnl(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::True if n == 0

    n.times {Line.newline}
    return Result::True
  end

  # Twiddles the two characters on either side of
  # dot. If dot is at the end of the line, twiddles the
  # two characters before it. Returns with an error if dot
  # is at the beginning of line.  This fixes up a very
  # common typo with a single stroke. Normally bound
  # to "C-T".
  def twiddle(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context
    return Result::False unless Files.checkreadonly

    # Copy the dot offset so that we can leave dot unchanged.
    doto = dot.o

    # Fetch the line text and its size
    text = lp.text
    lsize = lp.text.size

    # If dot is at the end of the line, back up one character.
    if doto == lsize
      doto -= 1
      return Result::False if doto < 0
    end

    # Get characters to the right and left of the dot.
    cr = text[doto, 1]
    doto -= 1
    return Result::False if doto < 0
    cl = text[doto, 1]

    # Get the strings to the left and right of the chacters
    # being twiddled.
    if doto == 0
      sl = ""
    else
      sl = text[0 .. doto-1]
    end
    if doto >= lsize - 1
      sr = ""
    else
      sr = text[doto+2 .. -1]
    end
    lp.value.text = sl + cr + cl + sr

    # Move the dot forward by one, unless we're at the end of the line.
    if dot.o < lsize
      dot.o += 1
    end

    # Mark the buffer as changed.
    b.lchange

    return Result::True
  end

  # Creates key bindings for all Misc commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('='), cmdptr(showcpos), "display-position")
    k.add(' '.ord, cmdptr(selfinsert), "ins-self")
    k.add(Kbd.ctrl('m'), cmdptr(insnl), "ins-nl")
    k.add(Kbd.ctrl('o'), cmdptr(openline), "ins-nl-and-backup")
    k.add(Kbd.ctrl('t'), cmdptr(twiddle), "twiddle")

    # Create bindings for each ASCII printable character.
    ('!'.ord .. '~'.ord).each do |c|
      k.add_dup(c, "ins-self")
    end
  end
end
