require "./ll"
require "./line"
require "./util"
require "./undo"

@[Flags]
# `Bflags` defines flags used in the `flags` property of a `Buffer` object.
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
  # Linked list of lines.
  property list : LinkedList(Line)

  # Flags (defined in `Bflags`).
  property flags : Bflags

  # Name (not filename)
  property name : String

  # File name (blank if not set).
  property filename : String

  # Number of windows using this buffer.
  property nwind : Int32

  # Cache of line numbers.
  property lcache : LineCache

  # Cache of buffer size.
  property scache : Int32

  # Undo/redo stacks.
  property undo : Undo

  # The `dot`, `mark` and `leftcol` properties are only used when a window is attached
  # or detached from this buffer.  When the last window is detached, we save that
  # window's values, so that the next time a window is attached, we
  # copy them to that window.  See `Window#add_wind` for details.
  
  # Current cursor position in buffer.
  property dot : Pos

  # Current mark position in buffer (not set if mark.l is -1)
  property mark : Pos

  # Left screen column of window.
  property leftcol : Int32

  # The `keymap` and `modename` properties are used to implement a Mode feature,
  # which allows key bindings to be associated with a buffer, rather
  # than being global.

  # Set of key bindings specific to this buffer.
  property keymap : KeyMap

  # Name of mode; if empty, keymap is not used.
  property modename : String

  # These properties are obtained from .editorconfig file(s), or
  # or if not defined there, default values are provided.

  # Number of columns used to represent a tab character.
  property tab_width = 8

  # True if tabs can be used for indentation (indent_style in .editorconfig).
  property use_tabs_to_indent = true

  # Number of columns to use for an indentation level.
  property indent_size = 2

  # True to ensure that the file ends with newline when saving.
  property insert_final_newline = true

  # True if trailing whitespace should be removed from lines when saving.
  property trim_trailing_whitespace = false

  # Characters to be used as line separators when saving.
  property end_of_line = "\n"

  # Character set (use `iconv -l` to get the complete list)
  property charset = "UTF-8"

  # Language to use for ispell.
  property spelling_language = ""

  # Class variables.

  # List of all buffers.
  @@blist = [] of Buffer

  # Special "system" buffer.
  @@sysbuf : Buffer | Nil

  # True if tabs are preserved when writing files.
  @@savetabs = true

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
    @undo = Undo.new
    @keymap = KeyMap.new
    @modename = ""

    # Add a blank line.
    @list.push(Line.alloc(""))

    # Create an empty line number cache.
    @lcache = LineCache.new

    # Create the size cache.
    @scache = -1

    # Set some properties from .editorconfig file(s).
    set_config_values

    # Add buffer to the list.
    @@blist.push(self)
  end

  # Instance methods.

  # Read .editorconfig values that apply to this buffer's filename.
  # Set some default values if no relevant config values are found.
  private def set_config_values
    # Set the default values.
    @tab_width = 8
    @indent_size = 2
    @use_tabs_to_indent = true
    @insert_final_newline = true
    @trim_trailing_whitespace = false
    @end_of_line = "\n"
    @charset = "UTF-8"

    # If the filename is blank, we don't need to searh config files.
    return if filename.size == 0

    # Get the tab_width value.
    cfg = E.config
    val = cfg.getvalue(@filename, "tab_width")
    if val =~ /^(\d+)$/
      @tab_width = val.to_i
    end

    # Get the indent_size value.
    val = cfg.getvalue(@filename, "indent_size").downcase
    if val == "tab"
      @indent_size = @tab_width
    elsif val =~ /^(\d+)$/
      @indent_size = val.to_i
    end

    # Get the indent_style value.
    val = cfg.getvalue(@filename, "indent_style").downcase
    if val == "tab"
      @use_tabs_to_indent = true
    elsif val == "space"
      @use_tabs_to_indent = false
    end

    # Get the insert_final_newline value.
    val = cfg.getvalue(@filename, "insert_final_newline").downcase
    if val == "true"
      @insert_final_newline = true
    elsif val == "false"
      @insert_final_newline = false
    end

    # Get the trim_trailing_whitespace value.
    val = cfg.getvalue(@filename, "trim_trailing_whitespace").downcase
    if val == "true"
      @trim_trailing_whitespace = true
    elsif val == "false"
      @trim_trailing_whitespace = false
    end

    # Get the end_of_line value.
    val = cfg.getvalue(@filename, "end_of_line").downcase
    if val == "lf"
      @end_of_line = "\n"
    elsif val == "cr"
      @end_of_line = "\r"
    elsif val == "crlf"
      @end_of_line = "\r\n"
    end

    # Get the charset value.
    val = cfg.getvalue(@filename, "charset").downcase
    case val
    when "latin1", "utf-8", "utf-16be", "utf-16le"
      @charset = val.upcase
    end

    # Get the spelling_language value.  This is used by spelling commands.
    # If it is missing or blank, no language will be specified.
    @spelling_language = cfg.getvalue(@filename, "spelling_language").downcase
  end

  # Sets the buffer filename, then reads .editorconfig information
  # for that filename.
  def filename=(fname : String)
    #STDERR.puts "Setting buffer filename to #{fname}"
    @filename = fname
    set_config_values
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
    if last_line.text.size != 0 && @insert_final_newline
      result = Echo.yesno("File doesn't end with a newline. Should I add one")
      return false if result == ABORT
      addline("") if result == TRUE
    end

    Echo.puts("[Writing...]")
    nline = 0
    begin
      File.open(@filename, "w") do |f|
        f.set_encoding(@charset, invalid: :skip)
        self.each do |lp|
	  if @trim_trailing_whitespace
	    text = lp.text.rstrip
	  else
	    text = lp.text
	  end
	  if @@savetabs
	    f.print(text)
	  else
	    f.print(text.detab)
	  end
	  if lp == last_line
	    nline += 1 if lp.text.size != 0
	  else
	    f.print(@end_of_line)
	    nline += 1
	  end
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

  # Clears the buffer, and reads the file `filename` into the buffer.
  # Returns true if successful, false otherwise
  def readin(@filename) : Bool
    @list.clear
    lastnl = true
    if !File.exists?(@filename)
      # If the file doesn't exist, it must be new, so just add a single empty line.
      Echo.puts("[New file]")
    else
      begin
	File.open(@filename) do |f|
	  f.set_encoding(@charset, invalid: :skip)
	  nline = 0
	  lastnl = true	# Pretend there's a blank line if file is empty
	  delimiter = (@end_of_line == "\r") ? '\r' : '\n'
	  while s = f.gets(delimiter: delimiter, chomp: false)
	    l = Line.alloc(s.chomp.scrub)
	    if s.size == 0 
	      lastnl = true
	    else
	      lastnl = s[-1] == delimiter
	    end
	    @list.push(l)
	    nline += 1
	  end
	  Echo.puts("[Read #{nline} line" + (nline == 1 ? "" : "s") + "]")
	end
      rescue ex
	Echo.puts("Cannot open #{@filename} for reading")
	lastnl = true
      end

    end

    # Add a blank line if the last line read ended with a newline,
    # or if no lines were read.
    addline("") if lastnl

    # Mark the buffer as unchanged.
    changed(false)

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

  # Returns the number of lines in the buffer.  Uses the size cache (@scache)
  # if it's valid; otherwise does it the hard way.
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

  # Returns the `n`th line in the buffer, or nil if `n` is too large.
  # `n` is zero-based, not 1-based.
  #
  # The hard way to do this is inefficient because it requires scanning the
  # entire linked list of lines.  We use a cache of line pointers indexed
  # by line number to avoid having do it the hard way every time.
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
  # line number and the line itself.  If the block returns false,
  # abort the iteration.
  def each_line
    n = 0
    @list.each do |l|
      return if !yield n, l
      n += 1
    end
  end

  # Iterates over each line in the line number range `low` to
  # `high`, inclusive, yielding both the line number and the line itself.
  # Line numbers are zero-based.
  def each_in_range(low : Int32, high : Int32)
    lp = self[low]
    return unless lp
    while low <= high
      yield low, lp
      break if lp == self.last_line
      lp = lp.next
      low += 1
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
  def changed(state : Bool = true)
    if state
      @flags = @flags | Bflags::Changed
    else
      @flags = @flags & ~Bflags::Changed
    end
  end

  # Clears the line number cache.    If *sizeadjust* is zero, clears
  # the size cache.  If the size cache is valid, and *sizeadjust* is
  # non-zero, adds *sizeadjust* to the size cache.
  def clear_caches(sizeadjust : Int32)
    @lcache.clear
    if sizeadjust == 0
      @scache = -1
    elsif @scache != -1
      @scache += sizeadjust
    end
  end

  # Deletes the line *lp* from the line list.
  def delete(lp : Pointer(Line))
    @list.delete(lp)
    clear_caches(-1)
  end

  # Adds an entry to the line cache assocating line number *n*
  # with line pointer *lp*.
  def add_cache(n : Int32, lp : Pointer(Line))
    @lcache[n] = lp
    #STDERR.puts("add_cache: n #{n}, lp #{lp}, text '#{lp.text}'")
  end

  # Inserts the line *lp1* after the line *lp* in the list.
  def insert_after(lp : Pointer(Line), lp1 : Pointer(Line))
    @list.insert_after(lp, lp1)
    clear_caches(1)
  end

  # Appends the string *s* to the buffer as a separate line.
  def addline(s : String)
    @list.push(Line.alloc(s))
    clear_caches(1)
  end

  # This routine blows away all of the text
  # in a buffer. If the buffer is marked as changed
  # then we ask if it is ok to blow it away; this is
  # to save the user the grief of losing text. The
  # window chain is nearly always wrong if this gets
  # called; the caller must arrange for the updates
  # that are required. Return true if everything
  # looks good.
  def clear : Bool
    if @flags.changed? && !@flags.system?
      if Echo.yesno("Discard changes") != TRUE
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

    # Clear the line number and size caches.
    clear_caches(0)

    # Update all windows viewing this buffer.
    Window.each do |w|
      if w.buffer == self
	w.dot = @dot
	w.mark = @mark
      end
    end

    return true
  end

  # Forces a line number to fall within the valid line
  # number range (0 to buffer size - 1).
  def clamp(line : Int32) : Int32
    last = self.size - 1
    if line < 0
      return 0
    elsif line > last
      return last
    else
      return line
    end
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

  # Returns the special system buffer, creating it first if necessary.
  def self.sysbuf : Buffer
    if @@sysbuf.nil?
      if b = Buffer.new("*sysbuf*")
	@@sysbuf = b
	b.flags = Bflags::System
	@@blist.delete(b)	# Remove it from the buffer list
	return b
      end
    end
    b = @@sysbuf
    if b.nil?
      raise "Unable to create sysbuf!"
    end
    b.flags = b.flags | Bflags::ReadOnly
    return b
  end

  # This routine rebuilds the text in the special buffer
  # that holds the buffer list. It is called
  # by the `listbuffers` command. Returns true
  # if everything works. Return false if there
  # is an error.
  def self.makelist : Bool
    # Create the system buffer if necessary.
    b = sysbuf
    b.clear

    # Find the largest buffer name.  Take extra care to correctly pad
    # buffer names smaller than the "Buffer" header.
    namesize = 0
    bhdr = "Buffer"
    bhdrsize = bhdr.size
    bhdrdashes = "-" * bhdrsize
    namesize = [Buffer.buffers.map {|b| b.name.size}.max, bhdrsize].max

    # Populate the system buffer with information about all buffers.
    b.addline("C W           Size " + bhdr.pad_right(namesize)       + " File")
    b.addline("- -           ---- " + bhdrdashes.pad_right(namesize) + " ----")
    Buffer.each do |b2|
      #STDERR.puts("makelist: b2 name #{b2.name}, nwind #{b2.nwind}")
      # Calculate number of bytes in this buffer.
      bytes = 0
      b2.each_line do |n,l|
	bytes += l.text.bytesize + 1
	true # tell each_line to continue
      end
      bytes -= 1	# adjust for last line

      line = String.build do |s|
	if b2.flags.changed?
	  s<< "* "
	else
	  s<< "  "
	end
	s << b2.nwind.to_s.pad_right(3)
	s << " "
	s << bytes.to_s.pad_left(12)
	s << " "
	s << b2.name.pad_right(namesize)
	s << " "
	s << b2.filename
      end
      b.addline(line)
    end
    return true
  end

  # Pops the special buffer onto the screen. This is used
  # by the `listbuffers` command and by other commands.
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
      #STDERR.puts("popsysbuf: setting popup buffer to #{b.name}, buffer size #{b.size}")
      w.buffer = b
    end

    # Update each window that is using the system buffer by resetting
    # its top line to 0, its dot to (0,0), and its mark to undefined.
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
  # are any changed buffers. System buffers (*sysbuf* is the only one so far),
  # don't count.  Returns false if there are no changed buffers.
  def self.anycb : Bool
    Buffer.each do |b|
      if b.flags.changed? && !b.flags.system?
	return true
      end
    end
    return false
  end

  # Commands.

  # This command makes the next buffer in the buffer list the current buffer.
  def self.nextbuffer(f : Bool, n : Int32, k : Int32) : Result
    # Get the index of the current buffer.
    i = @@blist.index(E.curb)
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

    return TRUE
  end

  # This command makes the previous buffer in the buffer list the current buffer.
  def self.prevbuffer(f : Bool, n : Int32, k : Int32) : Result
    # Get the index of the current buffer.
    i = @@blist.index(E.curb)
    if i.nil?
      raise "Unknown buffer in Buffer.prevbuffer!"
    end
    if i == 0
      i = @@blist.size - 1
    else
      i -= 1
    end
    b = @@blist[i]
    E.curw.usebuf(b)

    return TRUE
  end

  # This command attaches a buffer to a window. The values of dot and mark come from the
  # buffer if the use count is 0. Otherwise, they come from some other window.
  def self.usebuffer(f : Bool, n : Int32, k : Int32) : Result
    result, bufn = Echo.getbufn("Use buffer [#{E.oldbufn}]: ")
    return result if result != TRUE

    # Search for a buffer.
    return FALSE unless b = Buffer.find(bufn, true)
    E.curw.usebuf(b)
    return TRUE
  end

  # This command disposes of a buffer, by name.
  # Asks for the name,  and looks it up (don't get too
  # upset if it isn't there at all!). Gets quite upset
  # if the buffer is being displayed. Clears the buffer (ask
  # if the buffer has been changed).  Bound to "C-X K".
  def self.killbuffer(f : Bool, n : Int32, k : Int32) : Result
    if @@blist.size == 1
      Echo.puts("Can't kill the only buffer")
      return FALSE
    end
    result, bufn = Echo.getbufn("Kill buffer: ")
    return result if result != TRUE

    # Search for a buffer.
    b = Buffer.find(bufn, false)
    if b.nil?
      Echo.puts("[Buffer not found]")
      return TRUE
    end

    # Can't delete it if it's on screen
    if b.nwind != 0
      Echo.puts("Buffer is being displayed")
      return FALSE
    end

    # Clear the buffer.  Return FALSE if the buffer
    # was changed and the user said don't discard it.
    if !b.clear
      return FALSE
    end

    # Find the buffer's index in the list, then remove
    # it from the list.
    i = @@blist.index(b)
    if i.nil?
      raise "Unknown buffer in Buffer.killbuffer!"
    end
    @@blist.delete_at(i)
    return TRUE
  end

  # This command displays the buffer list. This is done
  # in two parts. The `makelist` routine figures out
  # the text, and puts it in the special *sysbuf* buffer.
  # Then `popsysbuf` pops the data onto the screen. Bound to
  # "C-X C-B".
  def self.listbuffers(f : Bool, n : Int32, k : Int32) : Result
    return FALSE unless makelist
    return b_to_r(popsysbuf)
  end

  # This command sets the savetabs flag according to the numeric argument if present,
  # or toggles the value if no argument present.  If savetabs is
  # zero, tabs will will be changed to spaces when saving a file, by
  # replacing each tab with the appropriate number of spaces (as
  # determined by String.tabsize).
  def self.setsavetabs(f : Bool, n : Int32, k : Int32) : Result
    @@savetabs = f ? (n != 0) : !@@savetabs
    Echo.puts("[Tabs will " + (@@savetabs ? "" : "not ") +
	      "be preserved when saving a file]")
    return TRUE
  end

  # Binds keys for buffer commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd::F8, cmdptr(nextbuffer), "forw-buffer")
    k.add(Kbd::F10, cmdptr(prevbuffer), "back-buffer")
    k.add(Kbd.ctlx('b'), cmdptr(usebuffer), "use-buffer")
    k.add(Kbd.ctlx('k'), cmdptr(killbuffer), "kill-buffer")
    k.add(Kbd.ctlx_ctrl('b'), cmdptr(listbuffers), "display-buffers")
    k.add(Kbd.meta('i'), cmdptr(setsavetabs), "set-save-tabs")
  end

  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
