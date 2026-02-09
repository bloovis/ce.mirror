# The `Misc` module contains some commands for inserting and deleting text.
module Misc

  extend self

  # Returns the current column position of dot, taking into account tabs
  # and control characters.  The column is zero-based.
  def getcolpos : Int32
    w, b, dot, lp = E.get_context
    return lp.text.screen_width(dot.o)
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
      text = l.text
      if l == lp
	bytes_at_dot = bytes + text[0,dot.o].bytesize
      end
      bytes += text.bytesize + 1
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
	[c, dot.l + 1, dot.l - w.line + w.toprow + 1,
	 text.screen_width(dot.o) + 1,
	 percent, bytes])
    Echo.puts(s)
    return TRUE
  end

  # Inserts *n* copies of the key *k* at the current location.
  def selfinsert(f : Bool, n : Int32, k : Int32) : Result
    return FALSE if n < 0
    return TRUE if n == 0

    # Get the unmodified key code.
    c = k & Kbd::CHAR;

    # ASCII-fy normal control characters, i.e., characters
    # Ctrl-@, Ctrl-A, Ctrl-B, etc., up to Ctrl-_.
    if (k & Kbd::CTRL) != 0 && c >= '@'.ord && c <= '_'.ord
      c -= '@'.ord
    end

    # Insert *n* copies of the character.
    Line.insert(c.chr.to_s * n)
    return TRUE
  end

  # Opens up some blank space by inserting one or more newlines
  # and then backing up over them.
  def openline(f : Bool, n : Int32, k : Int32) : Result
    return FALSE if n < 0
    return TRUE if n == 0

    n.times {Line.newline}
    return Basic.backchar(f, n, Kbd::RANDOM)
  end

  # Inserts *n* newlines at the current location.
  def insnl(f : Bool, n : Int32, k : Int32) : Result
    return FALSE if n < 0
    return TRUE if n == 0

    n.times {Line.newline}
    return TRUE
  end

  # Twiddles the two characters on either side of
  # dot. If dot is at the end of the line, twiddles the
  # two characters before it. Returns with an error if dot
  # is at the beginning of line.  This fixes up a very
  # common typo with a single stroke. Normally bound
  # to "C-T".
  def twiddle(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context
    return FALSE unless Files.checkreadonly

    # If dot is at the end of the line, back up one character.
    if w.dot.o == lp.text.size
      return FALSE if w.dot.o == 0
      w.dot.o -= 1
    end

    # Get characters to the right and left of the dot.
    cr = Line.getc
    return FALSE if w.dot.o == 0
    w.dot.o -= 1
    cl = Line.getc

    # Put the characters into the line in reverse order.
    Line.putc(cr)
    Line.putc(cl)
    return TRUE
  end

  # Inserts a newline followed by the correct number of
  # tabs and spaces to get the desired indentation *nicol*. If *nonwhitepos*
  # (the offset of the first nonwhitepos in the current line) is
  # the end of the line, the line is completely white, so zero it out;
  # then if an argument was specified to the command, instead of
  # inserting a new line, just readjust the newly blanked line's indentation.
  def nlindent(nicol : Int32, nonwhitepos : Int32, f : Bool) : Result
    w, b, dot, lp = E.get_context
    linelen = lp.text.size

    if linelen > 0 && nonwhitepos == linelen
      # If the current line is all whitespace, erase it.
      w.dot.o = 0
      Line.delete(linelen, false)

      # Insert a newline if no numeric argument was provided.
      if !f
	return FALSE unless Line.newline
      end
    else
      # Current line is not all whitespace, so insert a newline.
      return FALSE unless Line.newline
    end

    # Adjust the indentation of the current line.
    s = String.indent(nicol)
    return b_to_r(Line.insert(s))
  end

  # Indents according to Ruby conventions.  Inserts a newline, then enough tabs
  # and spaces to match the indentation of the previous line.  If the previous
  # line starts with a block-start keyword, increase indentation by two spaces. If a
  # two-C-U argument was specified, reduce indentation by two spaces.
  # Otherwise retain the same indentation.
  def rubyindent(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context
    text = lp.text

    # Find indentation and the offset of the first non-whitespace 
    nicol, i = text.current_indent

    # Look at the string following the whitespace in the
    # current line to determine the indentation of the next line.
    # If any of certain magic tokens was found, or a single C-U argument
    # was specified, indent by two spaces.  If a two-C-U argument was
    # specified, unindent by two spaces.
    if (f && (n == 4)) ||
       text =~ /^\s*(def|if|when|for|else|elsif|class|module)\b/
      nicol += 2
    elsif f && (n == 16)
      nicol = nicol < 2 ? 0 : nicol - 2
    end

    # Insert a newline followed by the correct number of
    # tabs and spaces to get the desired indentation.
    return nlindent(nicol, i, f)
  end

  # Deletes forward. This is easy, because the basic delete routine does
  # all of the work. Watches for negative arguments,
  # and does the right thing. If any argument is
  # present, it kills rather than deletes, to prevent
  # loss of text if typed with a big argument.
  # Normally bound to "C-D".
  def forwdel(f : Bool, n : Int32, k : Int32) : Result
    return backdel(f, -n, Kbd::RANDOM) if n < 0

    # If a numeric prefix was specified, zero out the kill buffer.
    Line.kdelete if f

    return b_to_r(Line.delete(n, f))
  end

  # Deletes backwards. This is quite easy too,
  # because it's all done with other functions. Just
  # move the cursor back, and delete forwards.
  # Like delete forward, this actually does a kill
  # if presented with an argument.
  def backdel(f : Bool, n : Int32, k : Int32) : Result
    return forwdel(f, -n, Kbd::RANDOM) if n < 0

    # If a numeric prefix was specified, zero out the kill buffer.
    Line.kdelete if f

    if Basic.backchar(f, n, Kbd::RANDOM) == TRUE
      return b_to_r(Line.delete(n, f))
    else
      return FALSE
    end
  end

  # Kill line. If called without an argument,
  # it kills from dot to the end of the line, unless it
  # is at the end of the line, when it kills the newline.
  # If called with an argument of 0, it kills from the
  # start of the line to dot. If called with a positive
  # argument, it kills from dot forward over that number
  # of newlines. If called with a negative argument it
  # kills any text before dot on the current line,
  # then it kills back abs(arg) lines.
  def killline(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context

    # Purge the kill buffer.
    Line.kdelete

    chunk = 0
    if !f
      # No argument: kill from dot to end of line.
      chunk = [lp.text.size - dot.o, 1].max
    elsif n > 0
      # Positive argument: kill from dot forward over n lines.
      chunk = lp.text.size - dot.o + 1	# +1 for newline
      (n - 1).times do
	break if lp == b.last_line
	lp = lp.next
	chunk += lp.text.size + 1
      end
    else
      # Negative argument: kill text before dot on current line,
      # then kill back -n lines.
      chunk = dot.o
      dot.o = 0
      n = -n
      n.times do
	break if lp = b.first_line
	lp = lp.previous
	dot.l -= 1
	chunk += lp.text.size
      end
    end
    return b_to_r(Line.delete(chunk, true))
  end

  # Yanks text back from the kill buffer. This
  # is really easy. All of the work is done by the
  # standard insert routines.
  def yank(f : Bool, n : Int32, k : Int32) : Result
    return FALSE if n < 0
    return TRUE if n == 0

    w, b, dot, lp = E.get_context
    n.times do
      return FALSE unless Line.insertwithnl(Line.kbuf)
    end
    return TRUE
  end

  # Sets the tab size according to the numeric argument.
  def settabsize(f : Bool, n : Int32, k : Int32) : Result
    if f
      if n < 2 || n > 32
	Echo.puts("Illegal tab size #{n}")
	return FALSE
      end
    else
      n = 8 unless f	# reset to default if no argument
    end
    String.tabsize = n
    Echo.puts("[Tab size set to #{n} characters]")
    return TRUE
  end

  # Prompts for a string of hex numbers separated by spaces.
  # Treats each hex number as a Unicode character, convert
  # it to UTF-8, and insert into the current buffer.
  def unicode(f : Bool, n : Int32, k : Int32) : Result
    result, s = Echo.reply("Enter Unicode characters in hex: ", nil)
    return result if result != TRUE
    chars = [] of Char
    s.split.each do |hex|
      if c = hex.to_i?(16)
	chars << c.chr
      else
	Echo.puts("Invalid hex number #{hex}")
	return FALSE
      end
    end
    chars.each {|ch| Line.insert(ch.to_s)}
    return TRUE
  end

  # Creates key bindings for all Misc commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('='), cmdptr(showcpos), "display-position")
    k.add(' '.ord, cmdptr(selfinsert), "ins-self")
    k.add(Kbd.ctrl('m'), cmdptr(insnl), "ins-nl")
    k.add(Kbd.ctrl('o'), cmdptr(openline), "ins-nl-and-backup")
    k.add(Kbd.ctrl('t'), cmdptr(twiddle), "twiddle")
    k.add(Kbd.ctrl('j'), cmdptr(rubyindent), "ruby-indent")
    k.add(Kbd.ctrl('k'), cmdptr(killline), "kill-line")
    k.add(Kbd.ctrl('y'), cmdptr(yank), "yank")
    k.add(Kbd.ctrl('d'), cmdptr(forwdel), "forw-del-char")
    k.add(Kbd.ctrl('h'), cmdptr(backdel), "back-del-char")
    k.add(Kbd.meta_ctrl('i'), cmdptr(settabsize), "set-tab-size")
    k.add_dup(Kbd::DEL, "forw-del-char")
    k.add(Kbd.meta_ctrl('u'), cmdptr(unicode), "unicode")

    # Create bindings for all ASCII printable characters and tab.
    ('!'.ord .. '~'.ord).each do |c|
      k.add_dup(c, "ins-self")
    end
    k.add_dup(Kbd.ctrl('i'), "ins-self")
  end
end
