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

  # These properties are only used when a window is attached or detached
  # from this buffer.  When the last window is detached, we save that
  # window's values, so that the next time a window is attached, we
  # copy them to that window.  See `Window#addwind` for details.
  property dot : Pos		# current cursor position in buffer
  property mark : Pos		# mark position
  property leftcol : Int32	# left column of window

  @@list = [] of Buffer

  def initialize(name, @filename = "")
    # If the user specified a filename, use the base name
    # as the buffer name.
    if filename.size > 0
      name = Path[filename].basename
    end
    newname = name

    # If there is already a buffer with the same name, keep
    # appending a suffix of the form ".N", with increasing values
    # for N, until we find a unique name.
    tries = 0
    newname = name
    while b = Buffer.find(newname) && tries < 100
      newname = name + "." + tries.to_s
      tries += 1
    end
    if tries == 100
      raise "Too many buffers with a name like #{name}!"
    end
    @name = newname

    # Initialize the rest of the instance variables
    @list = LinkedList(Line).new
    @flags = Bflags::None
    @nwind = 0
    @dot = Pos.new(0, 0)
    @mark = Pos.new(-1, 0)	# -1 means not set
    @leftcol = 0

    # Add a blank line
    @list.push(Line.alloc(""))

    # Add this new Buffer to the list.
    @@list.push(self)
  end

  # Instance methods.

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

  # Returns the first line in the buffer.
  def first_line : Pointer(Line)
    if empty?
      raise "Empty buffer in first_line!"
    end
    return @list.head
  end

  # Returns the last line in the buffer.
  def last_line : Pointer(Line)
    if empty?
      raise "Empty buffer in last_line!"
    end
    return @list.head.value.previous
  end

  # Sets the changed flag for the buffer.
  def lchange
    @flags = @flags | Bflags::Changed
  end

  # Class methods.

  # Finds the buffer with the name *name*, or returns nil if not found
  def self.find(name : String) : Buffer | Nil
    @@list.each do |b|
      return b if b.name == name
    end
    return nil
  end

  # Returns the list of all buffers.
  def self.buffers : Array(Buffer)
    @@list
  end

  # Commands.

  # Makes the next buffer in the buffer list the current buffer.
  def self.nextbuffer(f : Bool, n : Int32, k : Int32) : Result
    # Get the index of the current buffer.
    i = @@list.index(E.curw.buffer)
    if i.nil?
      raise "Unknown buffer in Buffer.nextbuffer!"
    end
    if i == @@list.size - 1
      i = 0
    else
      i += 1
    end
    b = @@list[i]
    E.curw.usebuf(b)

    return Result::True
  end

  # Binds keys for buffer commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd::F8, cmdptr(nextbuffer), "forw-window")
  end

  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
