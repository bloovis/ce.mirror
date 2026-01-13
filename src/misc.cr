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

  # Inserts *n* newlines at the current location.
  def insnl(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::True if n == 0

    n.times {Line.newline}
    return Result::True
  end

  # Creates key bindings for all Misc commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('='), cmdptr(showcpos), "display-position")
    k.add(' '.ord, cmdptr(selfinsert), "ins-self")
    k.add(Kbd.ctrl('m'), cmdptr(insnl), "ins-nl")

    # Create bindings for each ASCII printable character.
    ('!'.ord .. '~'.ord).each do |c|
      k.add_dup(c, "ins-self")
    end
  end
end
