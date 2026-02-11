# The `Region` class contains information about a region, i.e., the portion
# of a buffer between two `Pos` positions.  It also contains some commands
# for dealing with regions.
class Region

  # Starting position of the region.
  property start : Pos

  # Ending position of the region.
  property finish : Pos

  # The size of the region in characters.
  property size : Int32

  # This helper function examines the two positions *pos1* and *pos2*,
  # and determines their proper order and the size of the region
  # between the two positions.  It returns a tuple containing
  # the starting position, the ending position, and the size.
  protected def self.make_region(pos1 : Pos, pos2 : Pos) : Tuple(Pos, Pos, Int32)
    # Get the number of lines in the buffer.
    b = E.curb
    bsize = b.size

    # Determine which is first: pos1 or pos2?
    if pos1.l < pos2.l
      # Pos1 is before pos2.
      start = pos1.dup
      finish = pos2.dup
    elsif pos1.l == pos2.l
      # Pos2 and pos1 are on the same line.  This is the easy case:
      # set the distance between the two offsets.
      if pos2.o < pos1.o
	start = pos2.dup
	finish = pos1.dup
	rsize = pos1.o - pos2.o
      else
	start = pos1.dup
	finish = pos2.dup
	rsize = pos2.o - pos1.o
      end
      return {start, finish, rsize}
    else
      # Pos1 is after pos2.
      start = pos2.dup
      finish = pos1.dup
    end

    # Save the starting line and offset, and get the pointer
    # to the starting line.
    startl = start.l
    starto = start.o
    lp = b[startl]

    # lp should never be nil, but if it is, return
    # an empty region with an invalid Pos.
    if lp.nil?
      Echo.puts "Invalid line number #{startl}"
      start.l = -1
      finish.l = -1
      rsize = 0
      return {start, finish, rsize}
    end

    # Calculate the size of the region.  Be careful
    # not to go past the end of buffer.
    rsize = lp.text.size - starto + 1	# +1 for newline
    while startl + 1 < bsize
      startl += 1
      lp = lp.next
      if startl == finish.l
	rsize += finish.o
	break
      else
	rsize += lp.text.size + 1
      end
    end
    return {start, finish, rsize}
  end

  # The default `Region` constructor calculates the size of the region
  # between the current window's dot and mark.
  def initialize
    w = E.curw
    dot = w.dot
    mark = w.mark

    # If there is no mark in current window, display an error message
    # and return a region that has invalid Pos members, i.e., pos.l is -1.
    if mark.l == -1
      Echo.puts("No mark in this window")
      @start = Pos.new(-1, 0)
      @finish = Pos.new(-1, 0)
      @size = 0
      return
    end

    # Use the helper function to do the hard work.
    @start, @finish, @size = Region.make_region(dot, mark)
  end

  # This `Region` constructor calculates the size of the region
  # between the positions *pos1* and *pos2*.
  def initialize(pos1 : Pos, pos2 : Pos)
    # Use the helper function to do the hard work.
    @start, @finish, @size = Region.make_region(pos1, pos2)
  end

  # Commands.

  # This command kills the region. Move "." to the start, and kill the
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

  # This command copies all of the characters in the
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
	chunk = {lp.text.size - region.start.o, region.size}.min
	Line.kinsert(lp.text[region.start.o, chunk])
	region.start.o += chunk
	region.size -= chunk
      end
    end
    Echo.puts("[Region copied]")
    return TRUE
  end

  # This command adjusts the indentation of the lines in the region by the number of
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
      new_indent = {col + n, 0}.max

      # Replace the line text with the proper indentation prefix,
      # plus the part of the line after the leading whitespace.
      Line.delete(offset, false)
      Line.insert(String.indent(new_indent))

      # Move the next line.  Stop if we're at the line buffer line.
      break if lp == b.last_line
      lp = lp.next
      w.dot.l += 1
      w.dot.o = 0
    end
    return TRUE
  end

  # Creates key bindings for all `Region` commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctrl('w'), cmdptr(killregion), "kill-region")
    k.add(Kbd.meta('w'), cmdptr(copyregion), "copy-region")
    k.add(Kbd.meta('+'), cmdptr(indentregion), "indent-region")
  end

end
