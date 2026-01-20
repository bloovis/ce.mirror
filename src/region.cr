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
      startpos = mark.dup
      lp = b[startpos.l]
      if lp.nil?
	# lp should never be nil, but if it is, return
	# an empty region with an invalid Pos.
	Echo.puts "Invalid line number #{startpos.l}"
	@pos.l = -1
	@size = 0
	return
      end
      endpos = dot.dup
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
      startpos = dot.dup
      endpos = mark.dup
    end

    # Get region size, i.e. number of characters between startpos (inclusive)
    # and endpos (exclusive).
    @size = lp.text.size - startpos.o + 1	# +1 for newline
    while startpos.l + 1 < bsize
      startpos.l += 1
      lp = lp.next
      if startpos.l == endpos.l
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

  # Creates key bindings for all Word commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctrl('w'), cmdptr(killregion), "kill-region")
  end

end


