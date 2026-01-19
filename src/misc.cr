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
	[c, dot.l + 1, dot.l - w.line + w.toprow + 1,
	 Display.screen_size(text, dot.o) + 1,
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

  # Finds the first non-whitespace character in the string *s*, and returns a tuple
  # containing these two values:
  # * the on-screen column of that character (taking tabs into account)
  # * the index of that character in *s*
  # of that character.
  def currentindent(s : String) : Tuple(Int32, Int32)
    # Look for the first non-whitespace character.  If not found,
    # pretend that the non-whitespace character is just past
    # the end of the string.
    i = s.index(/\S/)
    if i.nil?
      i = s.size
    end

    # Return the display size and the offset.
    return {Display.screen_size(s, i), i}
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
      lp.text = ""
      w.dot.o = 0

      # Insert a newline if no numeric argument was provided.
      if !f
	return Result::False unless Line.newline
      end
    else
      # Current line is not all whitespace, so insert a newline.
      return Result::False unless Line.newline
    end

    # Adjust the indentation of the current line.
    i = nicol // Tabs.tabsize
    s = ""
    if i != 0
      s = "\t" * i
    end
    i = nicol % Tabs.tabsize
    if i != 0
      s = s + (" " * i)
    end
    return b_to_r(Line.insert(s))
  end

  # Indents according to Ruby conventions.  Inserts a newline, then enough tabs
  # and spaces to match the indentation of the previous line.  If the previous
  # line starts with a block-start keyword, indent by two spaces. If a
  # two-C-U argument was specified, reduce indentation by two spaces.
  # Otherwise retain the same indentation.
  def rubyindent(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context
    text = lp.text

    # Find indentation and the offset of the first non-whitespace 
    nicol, i = currentindent(text)

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

    if Basic.backchar(f, n, Kbd::RANDOM) == Result::True
      return b_to_r(Line.delete(n, f))
    else
      return Result::False
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
    return Result::False if n < 0
    return Result::True if n == 0

    w, b, dot, lp = E.get_context
    n.times do
      Line.keach do |s|
        if s == "\n"
	  return Result::False unless Line.newline
	else
	  return Result::False unless Line.insert(s)
	end
      end
    end
    return Result::True
  end

  # Creates key bindings for all Misc commands.
  def self.bind_keys(k : KeyMap)
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

    # Create bindings for all ASCII printable characters and tab.
    ('!'.ord .. '~'.ord).each do |c|
      k.add_dup(c, "ins-self")
    end
    k.add_dup(Kbd.ctrl('i'), "ins-self")
  end
end
