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

  @@list = [] of Buffer

  def initialize(@name)
    @list = LinkedList(Line).new
    @flags = Bflags::None
    @nwind = 0
    @filename = ""
    @@list.push(self)
  end

  # Returns the list of all buffers.
  def self.buffers : Array(Buffer)
    @@list
  end

  # Clears the buffer, and reads the file `filename` into the buffer.
  # Returns true if successful, false otherwise
  def readfile(@filename) : Bool
    return false unless File.exists?(@filename)
    @list.clear
    File.open(@filename) do |f|
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

  # Iterates over each line in the buffer, yielding both the zero-based
  # line number and the line itself.
  def each_line
    n = 0
    @list.each do |l|
      return if !yield n, l
      n += 1
    end
  end

  # Iterates over each line in the line number range `low` to
  # `high`, inclusive, yielding both the line number and the line itself.
  # Aborts the iteration if the block returns false.  Line numbers
  # are zero-based.
  def each_in_range(low : Int32, high : Int32)
    n = 0
    @list.each do |l|
      return if n > high
      if n >= low
        return if !yield n, l
      end
      n += 1
    end
  end

  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
