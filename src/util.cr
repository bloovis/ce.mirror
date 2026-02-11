# Application-specific extensions to the `String` class.
class String
  @@tabsize = 8

  # Returns the current tab size (default is 8).
  def self.tabsize : Int32
    @@tabsize
  end

  # Sets the current tab size.
  def self.tabsize=(n : Int32)
    @@tabsize = n
  end

  # Splits the string into lines, and passes each line to the block.
  # It passes newlines (`\n`) as separate one-character strings, which
  # allows the block to handle them in a special way.  This also ensures
  # the correct behavior if the last line in the string does not
  # end in a newline.
  def split_lines(&b)
    offset = 0
    len = self.size
    while offset < len
      i = self.index('\n', offset)
      if i.nil?
	yield self[offset, len - offset]
	offset = len
      else
	if i > offset
	  # Don't yield zero-length strings.
	  yield self[offset, i - offset]
	end
	yield "\n"
	offset = i + 1
      end
    end
  end

  # Returns a copy of the string padded on the left with spaces to make
  # its size equal to *width*.
  def pad_left(width : Int32) : String
    pad = width - self.size
    " " * pad + self
  end

  # Returns a copy of the string padded on the right with spaces to make
  # the its size equal to *width*.
  def pad_right(width : Int32) : String
    pad = width - self.size
    self + " " * pad
  end

  # Returns the screen width of the first *n* characters of the string,
  # taking into account tab expansion, and control characters being
  # displayed as two characters (e.g., `^C` for Ctrl-C).
  def screen_width(n : Int32) : Int32
    width = 0
    self.each_char do |c|
      break if n == 0
      n -= 1
      if c == '\t'
	width += @@tabsize - (width % @@tabsize)
      elsif c.ord >= 0x00 && c.ord <= 0x1a
	width += 2
      else
	width += 1	# FIXME: should be unicode width!
      end
    end
    return width
  end

  # Returns a readable version of the string.  If *expand* is true,
  # tabs are expanded.  ASCII control characters (including tabs if *expand*
  # is false) are replaced by ^C, where C is the corresponding letter.
  # *leftcol* and *width* define the portion of the resulting string
  # that is actually returned, i.e., any characters whose position falls
  # outside that range are omitted.
  def readable(expand = false, leftcol = 0, width = 32767) : String
    col = 0
    rightcol = leftcol + width
    s = String.build do |str|
      self.each_char do |c|
        if c.ord == 0x09 && expand
	  while true
	    str << ' ' if col >= leftcol && col < rightcol
	    col += 1
	    break if (col % @@tabsize) == 0
	  end
	elsif c.ord >= 0x00 && c.ord <= 0x1a
	  str << '^' if col >= leftcol && col < rightcol
	  col += 1
	  str << c + '@'.ord  if col >= leftcol && col < rightcol
	  col += 1
	else
	  str << c if col >= leftcol && col < rightcol
	  col += 1
	end
      end
    end
    return s
  end

  # Finds the first non-whitespace character in the string, and returns a tuple
  # containing these two values:
  # * the on-screen column of that character (taking tabs into account)
  # * the index of that character in the string
  def current_indent : Tuple(Int32, Int32)
    # Look for the first non-whitespace character.  If not found,
    # pretend that the non-whitespace character is just past
    # the end of the string.
    i = self.index(/\S/)
    if i.nil?
      i = self.size
    end

    # Return the display size and the offset.
    return {self.screen_width(i), i}
  end

  # Returns a copy of the string with tabs replaced with the
  # equivalent number of spaces.
  def detab : String
    col = 0
    s = String.build do |str|
      self.each_char do |c|
        if c.ord == 0x09
	  while true
	    str << ' '
	    col += 1
	    break if (col % @@tabsize) == 0
	  end
	else
	  str << c
	  col += 1
	end
      end
    end
    return s
  end

  # Returns a string composed of tabs and spaces whose display size
  # is equal to *col*.
  def self.indent(col : Int32) : String
    return ("\t" * (col // @@tabsize)) + (" " * (col % @@tabsize))
  end

end
