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
      elsif c.ord >= 0x01 && c.ord <= 0x1a
	width += 2
      else
	width += 1	# FIXME: should be unicode width!
      end
    end
    return width
  end

  # Returns a readable version of the string, where ASCII
  # control characters (including Tab!) are replaced by ^C, where C is
  # the corresponding letter.
  def readable : String
    s = self.gsub do |c|
      if c.ord >= 0x00 && c.ord <= 0x1a
	"^" + (c + '@'.ord).to_s
      else
	c
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
    self.gsub(/([^\t]*)(\t)/) { $1 + " " * (@@tabsize - $1.size % @@tabsize) }
  end

  # Returns a string composed of tabs and spaces whose display size
  # is equal to *col*.
  def self.indent(col : Int32) : String
    return ("\t" * (col // @@tabsize)) + (" " * (col % @@tabsize))
  end

end
