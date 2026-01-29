require "./ll"
require "./line"
require "./util"

@[Flags]
enum Bflags
  Changed
  Backup
  ReadOnly
  System
end

# `LineCache` is a hash mapping line numbers to their corresponding
# Line pointers in the buffer.
alias LineCache = Hash(Int32, Pointer(Line))

class Buffer
  property list : LinkedList(Line)
  property flags : Bflags
  property name : String
  property filename : String
  property nwind : Int32	# Number of windows using this buffer
  property lcache : LineCache	# Cache of line numbers
  property scache : Int32	# Cache of buffer size

  # These properties are only used when a window is attached or detached
  # from this buffer.  When the last window is detached, we save that
  # window's values, so that the next time a window is attached, we
  # copy them to that window.  See `Window#add_wind` for details.
  property dot : Pos		# current cursor position in buffer
  property mark : Pos		# mark position
  property leftcol : Int32	# left column of window

  # Class variables.
  @@blist = [] of Buffer	# list of user-created buffers
  @@sysbuf : Buffer | Nil	# special "system" buffer

  def initialize(name : String, @filename = "")
    #STDERR.puts("Buffer.initialize: name #{name}, filename #{@filename}")
    # If the user specified a filename, use its basename
    # as the buffer name instead of `name`.
    if @filename.size > 0
      @filename = Files.tilde_expand(@filename)
      name = File.basename(@filename)
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

    # Add a blank line.
    @list.push(Line.alloc(""))

    # Create an empty line number cache.
    @lcache = LineCache.new

    # Create the size cache
    @scache = -1

    # Add buffer to the list.
    @@blist.push(self)
  end

  # Writes the buffer to its associated file.  Returns true
  # on success, false otherwise.
  def writeout : Bool
    if @filename == ""
      Echo.puts("No file name")
      return false
    end

    # Check if the file has no terminating newline.  This is the
    # case if the last line in the file is not empty.
    lp = last_line
    appendnl = false
    if lp.text.size != 0
      result = Echo.yesno("File doesn't end with a newline. Should I add one")
      return false if result == Result::Abort
      appendnl = result == Result::True
    end

    Echo.puts("[Writing...]")
    nline = 0
    begin
      File.open(@filename, "w") do |f|
        self.each do |lp|
	  f.print(lp.text)
	  if (lp != last_line) || appendnl
	    f.print("\n")
	  end
	  nline += 1
	end
      end
      Echo.puts("[Wrote #{nline} line" + (nline == 1 ? "" : "s") + "]")
      status = true
    rescue ex
      Echo.puts("Cannot open #{@filename} for writing")
      status = false
    end
    return status
  end

  # Instance methods.

  # Clears the buffer, and reads the file `filename` into the buffer.
  # Returns true if successful, false otherwise
  def readin(@filename) : Bool
    return false unless File.exists?(@filename)
    @list.clear

    if !File.exists?(@filename)
      # If the file doesn't exist, it must be new, so just add a single empty line.
      Echo.puts("[New file]")
      @list.push(Line.alloc(""))
    else
      File.open(@filename) do |f|
        nline = 0
	lastline = "\n"	# Pretend there's a blank line if file is empty
	while s = f.gets(chomp: false)
	  l = Line.alloc(s.chomp)
	  lastline = s
	  @list.push(l)
	  nline += 1
	end

	# If the last line ended in a newline, append
	# a blank line to the buffer, to give the user a place to
	# start adding new text.
	if lastline && lastline.size > 0 && lastline[-1] == '\n'
	  @list.push(Line.alloc(""))
	end

	Echo.puts("[Read #{nline} line" + (nline == 1 ? "" : "s") + "]")
      end
    end

    # Mark the buffer as unchanged.
    lchange(false)

    # For all windows that are viewing this buffer, set
    # the dot to the top of the buffer, and invalidate the mark.
    Window.each do |w|
      if w.buffer == self
	w.dot = Pos.new(0, 0)
	w.mark = Pos.new(-1, 0)
      end
    end

    # In case the buffer isn't in any window, set its dot to the top.
    @dot = Pos.new(0, 0)

    return true
  end

  # Returns the number of lines in the buffer.
  def size : Int32
    # Is the size already in the cache?
    if @scache != -1
      return @scache
    end

    # Size is not in the cache.  Calculate it the hard way.
    n = 0
    @list.each {|l| n += 1}
    @scache = n
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
    # Is the line already in the cache?
    if lp = @lcache[n]?
      return lp
    end

    # See if the previous line is in the cache.  If it is,
    # the line that follows it is the one we're looking for.
    if n > 0
      if lp = @lcache[n-1]?
	#STDERR.puts "found previous line #{n-1} in cache"
	lp = lp.next
	@lcache[n] = lp
	return lp
      end
    end

    # See if the next line is in the cache.  If it is, the
    # line that precedes it is the one we're looking for.
    if n < self.size - 1
      if lp = @lcache[n+1]?
	#STDERR.puts "found next line #{n+1} in cache"
	lp = lp.previous
	@lcache[n] = lp
	return lp
      end
    end

    # Line is not in the cache, must find it the hard way
    # and add it to the cache.
    lnno = -1
    lp = @list.find {|l| lnno += 1; lnno == n}
    if lp
      @lcache[n] = lp
    end
    return lp
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

  # Sets the changed flag for the buffer if *state* is true (default
  # if not specified), or clears the changed flag if *state* is false.
  def lchange(state : Bool = true)
    if state
      @flags = @flags | Bflags::Changed
    else
      @flags = @flags & ~Bflags::Changed
    end
  end

  # Deletes the line *lp* from the line list.
  def delete(lp : Pointer(Line))
    @list.delete(lp)
    @lcache.clear
    @scache = -1
  end

  # Inserts the line *lp1* after the line *lp* in the list.
  def insert_after(lp : Pointer(Line), lp1 : Pointer(Line))
    @list.insert_after(lp, lp1)
    @lcache.clear
    @scache = -1
  end

  # Appends the string *s* to the buffer as a separate line.
  def addline(s : String)
    @list.push(Line.alloc(s))
  end

  # This routine blows away all of the text
  # in a buffer. If the buffer is marked as changed
  # then we ask if it is ok to blow it away; this is
  # to save the user the grief of losing text. The
  # window chain is nearly always wrong if this gets
  # called; the caller must arrange for the updates
  # that are required. Return TRUE if everything
  # looks good.
  def clear : Bool
    if @flags.changed?
      if Echo.yesno("Discard changes") != Result::True
	return false
      end
    end

    # Clear all flags except System.
    @flags = @flags & Bflags::System

    # Clear the line list.
    @list.clear

    # Clear the dot and mark.
    @dot = Pos.new(0, 0)
    @mark = Pos.new(-1, 0)	# -1 means not set
    @leftcol = 0

    # Update all windows viewing this buffer.
    Window.each do |w|
      if w.buffer == self
	w.dot = @dot
	w.mark = @mark
      end
    end

    return true
  end

  # Class methods.

  # Searches for a buffer with the name `name`.
  # If not found, and `create` is true,
  # creates a buffer and put it in the list of
  # all buffers.  Return pointer to the buffer, or
  # nil if not found and `create` is false.
  def self.find(name : String, create : Bool = false) : Buffer | Nil
    Buffer.each do |b|
      return b if b.name == name
    end
    if create
      return Buffer.new(name, "")
    else
      return nil
    end
  end

  # Returns the list of all buffers.
  def self.buffers : Array(Buffer)
    @@blist
  end

  # Yields each buffer to the passed-in block
  def self.each
    @@blist.each {|b| yield b}
  end

  # Returns the secret system buffer, creating it first if necessary.
  def self.sysbuf : Buffer
    if @@sysbuf.nil?
      if b = Buffer.new("*sysbuf*")
	@@sysbuf = b
	b.flags = Bflags::System
	return b
      end
    end
    b = @@sysbuf
    if b.nil?
      raise "Unable to create sysbuf!"
    end
    return b
  end

  # This routine rebuilds the
  # text in the special secret buffer
  # that holds the buffer list. It is called
  # by the list buffers command. Return TRUE
  # if everything works. Return FALSE if there
  # is an error (if there is no memory).
  def self.makelist : Bool
    # Find the largest buffer name.  Take extra care to correctly pad
    # buffer names smaller than the "Buffer" header.
    namesize = 0
    bhdr = "Buffer"
    bhdrsize = bhdr.size
    bhdrdashes = "-" * bhdrsize
    Buffer.each do |b|
      next if b.flags.system?
      namesize = [b.name.size, namesize, bhdrsize].max
    end

    # Populate the system buffer with the information about the
    # "normal" buffers.
    b = sysbuf
    b.clear
    b.filename = ""
    b.addline("C W          Size " + bhdr.pad_right(namesize)       + " File")
    b.addline("- -          ---- " + bhdrdashes.pad_right(namesize) + " ----")
    Buffer.each do |b2|
      #STDERR.puts("makelist: b2 name #{b2.name}, nwind #{b2.nwind}")
      # Don't include system buffers in the list.
      next if b2.flags.system?

      # Calculate number of bytes in this buffer.  FIXME: this
      # actually calculates characters, not bytes.
      bytes = 0
      b2.each_line do |n,l|
	bytes += l.text.size + 1
	true # tell each_line to continue
      end
      bytes -= 1	# adjust for last line

      if b2.flags.changed?
	s = "* "
      else
	s = "  "
      end
      s = s +
	  b2.nwind.to_s.pad_right(2) + " " +
	  bytes.to_s.pad_left(12) + " " +
	  b2.name.pad_right(namesize) + " " + b2.filename
      b.addline(s)
    end
    return true
  end

  # Pops the special buffer onto the screen. This is used
  # by the "listbuffers" command and by other commands.
  # Returns a status.
  def self.popsysbuf : Bool
    b = sysbuf
    #STDERR.puts("popsysbuf: nwind #{b.nwind}")
    if b.nwind == 0
      # Not in screen yet, get a pop-up window for it.
      #STDERR.puts("popsysbuf: calling popup")
      w = Window.popup
      return false unless w

      # Stop using the window's current buffer, and make it use
      # the system buffer.
      #STDERR.puts("popsysbuf: setting popup buffer to #{b.name}")
      w.buffer = b
    end

    # Update all windows that are using the system buffer.
    Window.each do |w|
      if w.buffer == b
	w.line = 0
	w.dot = Pos.new(0, 0)
	w.leftcol = 0
	w.mark = Pos.new(-1, 0)
      end
    end

    return true
  end

  # Looks through the list of buffers and returns true if there
  # are any changed buffers. Special buffers like the buffer list
  # buffer don't count.  Returns false if there are no changed buffers.
  def self.anycb : Bool
    Buffer.each do |b|
      if b.flags.changed? && !b.flags.system?
	return true
      end
    end
    return false
  end

  # Commands.

  # Makes the next buffer in the buffer list the current buffer.
  def self.nextbuffer(f : Bool, n : Int32, k : Int32) : Result
    # Get the index of the current buffer.
    i = @@blist.index(E.curw.buffer)
    if i.nil?
      raise "Unknown buffer in Buffer.nextbuffer!"
    end
    if i == @@blist.size - 1
      i = 0
    else
      i += 1
    end
    b = @@blist[i]
    E.curw.usebuf(b)

    return Result::True
  end

  # Attaches a buffer to a window. The
  # values of dot and mark come from the buffer
  # if the use count is 0. Otherwise, they come
  # from some other window.
  def self.usebuffer(f : Bool, n : Int32, k : Int32) : Result
    result, bufn = Echo.getbufn
    return result if result != Result::True

    # Search for a buffer.
    return Result::False unless b = Buffer.find(bufn, true)
    E.curw.usebuf(b)
    return Result::True
  end

  # Display the buffer list. This is done
  # in two parts. The `makelist` routine figures out
  # the text, and puts it in the special sysbuf buffer.
  # Then `popsysbuf` pops the data onto the screen. Bound to
  # "C-X C-B".
  def self.listbuffers(f : Bool, n : Int32, k : Int32) : Result
    return Result::False unless makelist
    return b_to_r(popsysbuf)
  end

  # Binds keys for buffer commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd::F8, cmdptr(nextbuffer), "forw-window")
    k.add(Kbd.ctlx('b'), cmdptr(usebuffer), "use-buffer")
    k.add(Kbd.ctlx_ctrl('b'), cmdptr(listbuffers), "display-buffers")
  end

  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
