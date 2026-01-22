# The `Region` class contains some commands for dealing with regions.
class Region

  property pos : Pos		# starting position of region
  property size : Int32		# size of region in characters

  # The `Region` constructor calculates the starting position
  # and size of the region between the current window's dot
  # and mark.
  def initialize
    w, b, dot, lp = E.get_context
    mark = w.mark
    bsize = b.size

    # If there is no mark in current window, display an error message
    # and return a region that has an invalid Pos, i.e., pos.l is -1.
    if mark.l == -1
      Echo.puts("No mark in this window")
      @pos = Pos.new(-1, 0)
      @size = 0
      return
    end

    # Determine which is first: the mark or the dot?
    if mark.l < dot.l
      # Mark is before dot.
      @pos = mark.dup
      startl = mark.l
      starto = mark.o
      lp = b[startl]
      if lp.nil?
	# lp should never be nil, but if it is, return
	# an empty region with an invalid Pos.
	Echo.puts "Invalid line number #{startl}"
	@pos.l = -1
	@size = 0
	return
      end
      endpos = dot
    elsif mark.l == dot.l
      # Dot and mark are one the same line.  This is the easy case:
      # set the distance between the two offsets and return.
      if dot.o < mark.o
	@pos = dot.dup
	@size = mark.o - dot.o
      else
	@pos = mark.dup
	@size = dot.o - mark.o
      end
      return
    else
      # Mark is after dot.
      @pos = dot.dup
      startl = dot.l
      starto = dot.o
      endpos = mark
    end

    # Get region size, i.e. number of characters between startl/starto (inclusive)
    # and endpos (exclusive).
    @size = lp.text.size - starto + 1	# +1 for newline
    while startl + 1 < bsize
      startl += 1
      lp = lp.next
      if startl == endpos.l
	@size += endpos.o
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
    if region.pos.l == -1
      return Result::False
    end
    Line.kdelete
    E.curw.dot = region.pos
    return b_to_r(Line.delete(region.size, !f))
  end

  # Copy all of the characters in the
  # region to the kill buffer. Don't move dot
  # at all. This is a bit like a kill region followed
  # by a yank.
  def self.copyregion(f : Bool, n : Int32, k : Int32) : Result
    region = Region.new
    if region.pos.l == -1
      return Result::False
    end

    # Purge the kill buffer.
    Line.kdelete

    # Get a pointer to the starting line of the region.
    b = E.curw.buffer
    lp = b[region.pos.l]
    raise "Invalid line number #{region.pos.l} in copyregion!" if lp.nil?

    while region.size > 0
      if region.pos.o == lp.text.size
	# End of line.
	Line.kinsert("\n")
	lp = lp.next
	region.pos.o = 0
	region.size -= 1
      else
	# Middle of line.
	chunk = [lp.text.size - region.pos.o, region.size].min
	Line.kinsert(lp.text[region.pos.o, chunk])
	region.pos.o += chunk
	region.size -= chunk
      end
    end
    Echo.puts("[Region copied]")
    return Result::True
  end

  # Creates key bindings for all Region commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctrl('w'), cmdptr(killregion), "kill-region")
    k.add(Kbd.meta('w'), cmdptr(copyregion), "copy-region")
  end

end


