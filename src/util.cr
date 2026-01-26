# Application-specific extensions to standard classes.

class String
  # Splits a string into lines, and passes each line to the block.
  # It passes newlines (\n) as separate one-character strings, which
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

  # Returns this String padded on the left with spaces to make
  # its size equal to *width*.
  def pad_left(width : Int32)
    pad = width - self.size
    " " * pad + self
  end

  # Returns this String padded on the right with spaces to make
  # the its size equal to *width*.
  def pad_right(width : Int32)
    pad = width - self.size
    self + " " * pad
  end
end
