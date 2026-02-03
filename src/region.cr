# The `Region` class contains some commands for dealing with regions.
class Region

  property start : Pos		# starting position of region
  property finish : Pos		# ending position of region
  property size : Int32		# size of region in characters

  # The `Region` constructor calculates the starting and ending positions,
  # and size of the region between the current window's dot
  # and mark.
  def initialize
    w, b, dot, lp = E.get_context
    mark = w.mark
    bsize = b.size

    # If there is no mark in current window, display an error message
    # and return a region that has invalid Pos members, i.e., pos.l is -1.
    if mark.l == -1
      Echo.puts("No mark in this window")
      @start = Pos.new(-1, 0)
      @finish = Pos.new(-1, 0)
      @size = 0
      return
    end

    # Determine which is first: the mark or the dot?
    if mark.l < dot.l
      # Mark is before dot.
      @start = mark.dup
      @finish = dot.dup
      startl = mark.l
      starto = mark.o
      lp = b[startl]
      if lp.nil?
	# lp should never be nil, but if it is, return
	# an empty region with an invalid Pos.
	Echo.puts "Invalid line number #{startl}"
	@start.l = -1
	@finish.l = -1
	@size = 0
	return
      end
    elsif mark.l == dot.l
      # Dot and mark are one the same line.  This is the easy case:
      # set the distance between the two offsets and return.
      if dot.o < mark.o
	@start = dot.dup
	@finish = mark.dup
	@size = mark.o - dot.o
      else
	@start = mark.dup
	@finish = dot.dup
	@size = dot.o - mark.o
      end
      return
    else
      # Mark is after dot.
      @start = dot.dup
      @finish = mark.dup
      startl = dot.l
      starto = dot.o
    end

    # Get region size, i.e. number of characters between startl/starto (inclusive)
    # and endpos (exclusive).
    @size = lp.text.size - starto + 1	# +1 for newline
    while startl + 1 < bsize
      startl += 1
      lp = lp.next
      if startl == @finish.l
	@size += @finish.o
	return
      else
	@size += lp.text.size + 1
      end
    end
  end

  # Kills the region. Move "." to the start, and kill the
  # characters. If an argument is provided, don't put the
  # characters in the kill buffer.
  def self.killregion(f : Bool, n : Int32, k : Int32) : Result
    region = Region.new
    if region.start.l == -1
      return FALSE
    end
    Line.kdelete
    E.curw.dot = region.start.dup
    return b_to_r(Line.delete(region.size, !f))
  end

  # Copy all of the characters in the
  # region to the kill buffer. Don't move dot
  # at all. This is a bit like a kill region followed
  # by a yank.
  def self.copyregion(f : Bool, n : Int32, k : Int32) : Result
    region = Region.new
    if region.start.l == -1
      return FALSE
    end

    # Purge the kill buffer.
    Line.kdelete

    # Get a pointer to the starting line of the region.
    b = E.curb
    lp = b[region.start.l]
    raise "Invalid line number #{region.start.l} in copyregion!" if lp.nil?

    while region.size > 0
      if region.start.o == lp.text.size
	# End of line.
	Line.kinsert("\n")
	lp = lp.next
	region.start.o = 0
	region.size -= 1
      else
	# Middle of line.
	chunk = [lp.text.size - region.start.o, region.size].min
	Line.kinsert(lp.text[region.start.o, chunk])
	region.start.o += chunk
	region.size -= chunk
      end
    end
    Echo.puts("[Region copied]")
    return TRUE
  end

  # Adjusts the indentation of the lines in the region by the number of
  # spaces in the argument *n*, which can be negative to unindent.
  def self.indentregion(f : Bool, n : Int32, k : Int32) : Result
    region = Region.new
    if region.start.l == -1
      return FALSE
    end
    return FALSE unless Files.checkreadonly

    # Get the first line in the region.
    w = E.curw
    b = w.buffer
    w.dot = region.start
    w.dot.o = 0
    lp = b[region.start.l]
    return FALSE unless lp

    # Loop through every line in the region.
    while w.dot.l != region.finish.l
      # Calculate the current indentation of the line.
      text = lp.text
      col, offset = text.current_indent

      # The new indentation is the old indentation + n, but
      # cannot be less than zero.
      new_indent = [col + n, 0].max

      # Replace the line text with the proper indentation prefix,
      # plus the part of the line after the leading whitespace.
      Line.delete(offset, false)
      Line.insert(String.indent(new_indent))
      b.lchange

      # Move the next line.  Stop if we're at the line buffer line.
      break if lp == b.last_line
      lp = lp.next
      w.dot.l += 1
      w.dot.o = 0
    end
    return TRUE
  end

  # Creates key bindings for all Region commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctrl('w'), cmdptr(killregion), "kill-region")
    k.add(Kbd.meta('w'), cmdptr(copyregion), "copy-region")
    k.add(Kbd.meta('+'), cmdptr(indentregion), "indent-region")
  end

end
