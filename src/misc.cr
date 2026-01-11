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
    s = sprintf("[CH:0x%02X] Line:%d Row:%d Col:%d %d%% of %d]",
	[c, dot.l + 1, dot.l - w.line + w.toprow + 1, dot.o + 1,
	 percent, bytes])
    Echo.puts(s)
    return Result::True
  end

  # Creates key bindings for all Misc commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('='), cmdptr(showcpos), "display-position")
  end
end
