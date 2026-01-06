require "./ll"
require "./line"

@[Flags]
enum Bflags
  Changed
  Backup
  ReadOnly
end

class Buffer
  property list : LinkedList(Line)
  property flags : Bflags
  property name : String
  property filename : String
  property nwind : Int32

  def initialize(@name)
    @list = LinkedList(Line).new
    @flags = Bflags::None
    @nwind = 0
    @filename = ""
  end

  # Clears the buffer, and reads the file `filename` into the buffer.
  # Returns true if successful, false otherwise
  def readfile(filename : String) : Bool
    return false unless File.exists?(filename)
    @list.clear
    File.open(filename) do |f|
      lastline = nil
      while s = f.gets(chomp: false)
	l = Line.alloc(s.chomp)
	lastline = s
	@list.push(l)
      end

      # If the last line ended in a newline, append
      # a blank line to the buffer, to give the user a place to
      # start adding new text.
      if lastline && lastline.size > 0 && lastline[-1] == '\n'
	@list.push(Line.alloc(""))
      end
    end
    @flags = @flags & ~Bflags::Changed
    return true
  end

  # Returns the number of lines in the buffer.
  def size : Int32
    n = 0
    @list.each {|l| n += 1}
    return n
  end

  # Same as `size`, for Ruby compatibility.
  def length : Int32
    size
  end

  # Returns the zero-based line number of line `lp` .  If the line
  # is not found, returns the number of lines in the buffer,
  # which is not a valid line number.
  def lineno(lp : Pointer(Line) | Nil) : Int32
    return size unless lp
    lnno = -1
    f = @list.find {|l| lnno += 1; l == lp}
    if f
      return lnno
    else
      return lnno + 1
    end
  end

  # Returns the `n`th line in the buffer, or nil if `n` is too large.
  # `n` is zero-based, not 1-based.
  #
  # This is inefficient right now, but we can improve the algorithm
  # in the future by caching one or more line number => line associations.
  def [](n : Int32) : Pointer(Line) | Nil
    lnno = -1
    @list.find {|l| lnno += 1; lnno == n}
  end

  # Iterates over each line in the line number range `first` to
  # `last`, inclusive, yielding both the line number and the line itself.
  # Aborts the iteration if the block returns false.  Line numbers
  # are zero-based.
  def each_in_range(first : Int32, last : Int32)
    last = [last, size - 1].min
    first = [first, last].min
    lp = self[first]
    if lp
      (first..last).each do |i|
	return if !yield i, lp
	lp = lp.next
      end
    end
  end

  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
