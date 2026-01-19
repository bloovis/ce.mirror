require "./buffer"
require "./pos"

@[Flags]
enum Wflags
  Force		# Force reframe
  Move		# Movement from line to line
  Edit		# Editing within a line
  Hard		# Do a full display update
  Mode		# Update mode line
end

class Window
  property buffer : Buffer
  property line : Int32		# buffer line number of the window's top line
  property dot : Pos		# current cursor position in buffer
  property mark : Pos		# mark position
  property savep : Pos		# saved line position for search
  property toprow : Int32	# top screen row of window
  property nrow : Int32		# number of screen rows in window
  property leftcol : Int32	# left column of window
  property force : Int32	# if non-zero, force dot to be displayed at this row
  property flags : Wflags	# flags that give hints to the display updater

  @@list = [] of Window		# list of all windows
  @@curi = -1			# index to @@list of current window
  @@oldbufn = ""		# old buffer name

  def initialize(@buffer)
    # Initialize the various instance variables.
    @line = 0
    @dot = Pos.new()
    @mark = Pos.new(-1, 0)	# -1 means not set
    @savep = Pos.new()
    @toprow = 0
    @nrow = 0
    @leftcol = 0
    @force = 0
    @flags = Wflags::None

    # Bump the window count of the buffer.
    @buffer.nwind += 1

    # If this is the first window, make it the current one
    # and add to the global list.
    if @@curi == -1
      @@curi = 0
      @@list << self
    end
  end

  # Returns next window in list, or nil if this the last window
  def next : Window | Nil
    i = @@list.index[self]
    if i.nil?
      raise "Unknown window in Window#next!"
    end
    if i == @@list.size - 1
      return nil
    else
      return @@list[i + 1]
    end
  end

  # Returns previous window in list, or nil if this the last window
  def previous : Window | Nil
    i = @@list.index[self]
    if i.nil?
      raise "Unknown window in Window#previous!"
    end
    if i == 0
      return nil
    else
      return @@list[i - 1]
    end
  end

  # Adds *n*, which must be 1 or -1, to the window count of the buffer associated
  # with a window.  Copies the dot and mark from the window to the buffer
  # if the count goes to zero, or from the buffer to the window if
  # the count goes to one.
  def addwind(n : Int32)
    b = @buffer
    if b.nwind == 0
      # This is the first use of the buffer.  Copy the mark, dot,
      # and leftcol from the buffer to this window.
      @dot = Pos.new(b.dot)
      @mark = Pos.new(b.mark)
      @leftcol = b.leftcol
    end
    b.nwind += n
    if b.nwind == 0
      # This is the last use of the buffer.  Copy the mark, dot,
      # and leftcol from this window to the buffer.
      b.dot = Pos.new(@dot)
      b.mark = Pos.new(@mark)
      b.leftcol = @leftcol
    end
  end

  # Attach a buffer to this window. The
  # values of dot and mark come from the buffer
  # if the use count is 0. Otherwise, they come
  # from some other window.  This routine
  # differs from `usebuffer` in that it isn't a user command,
  # but expects a buffer pointer, instead of prompting the
  # user for a buffer name.
  def usebuf(b : Buffer)
    # Save the current buffer's name.
    @@oldbufn = @buffer.name

    # Decrement the window count of the old current buffer.
    addwind(-1)

    # Set the new current buffer and increment its window count.
    @buffer = b
    addwind(1)

    # If this is not the first use of the buffer, copy the mark,
    # dot, and leftcol values from the first other window we find that
    # is also using this buffer.
    Window.each do |w|
      if w != self && w.buffer == b
	@dot = Pos.new(w.dot)
	@mark = Pos.new(w.mark)
	@leftcol = w.leftcol
        break
      end
    end
    return Result::True
  end

  # Class methods.

  # Returns the current Window.
  def self.current : Window
    if @@curi >= 0 && @@curi < @@list.size
      return @@list[@@curi]
    else
      raise "Invalid current window index #{@@curi}!"
    end
  end

  # Sets the current Window.
  def self.current= (w : Window)
    i = @@list.index(w)
    if i
      @@curi = i
    else
      raise "Window #{w} is not in list!"
    end
  end

  # Yields each Window to the passed-in block.
  def self.each
    @@list.each do |window|
      yield window
    end
  end

  # Commands.

  # Makes the next window the current window, or does nothing
  # if there is only one window.
  def self.nextwind(f : Bool, n : Int32, k : Int32) : Result
    if @@curi == @@list.size - 1
      @@curi = 0
    else
      @@curi = @@curi + 1
    end
    return Result::True
  end

  # Makes the previous window the current window, or does nothing
  # if there is only one window.
  def self.prevwind(f : Bool, n : Int32, k : Int32) : Result
    if @@curi == 0
      @@curi = @@list.size - 1
    else
      @@curi = @@curi - 1
    end
    return Result::True
  end

  # Split the current window. A window
  # smaller than 3 lines cannot be split.
  # The only other error that is possible is
  # a "malloc" failure allocating the structure
  # for the new window.
  def self.splitwind(f : Bool, n : Int32, k : Int32) : Result
    w = Window.current
    if w.nrow < 3
      Echo.puts("Cannot split a #{w.nrow}-line window")
      return Result::False
    end

    # Create the Window object.
    w2 = Window.new(w.buffer)
    w2.dot = w.dot.dup
    w2.mark = w.mark.dup
    w2.force = w.force
    w2.leftcol = w.leftcol

    # Calculate the sizes of the upper and lower windows.
    upper_nrow = (w.nrow - 1) // 2
    lower_nrow = (w.nrow - 1) - upper_nrow

    # Calculate how many lines are visible above the dot
    # in the current window.
    above = w.dot.l - w.line

    # Set the proposed top line number of the two windows.
    # It may be adjusted later.
    line = w.line
    
    if above <= upper_nrow
      # If the dot is above or right on the split point, we
      # will make the old window be the upper window.
      # If the dot is right on the split point, i.e., where
      # the mode line is going to be, bump the top line number.
      if above == upper_nrow
	line += 1
      end

      # Insert the new window after the current window
      # in the window list.
      if @@curi == @@list.size - 1
	@@list << w2
      else
	@@list.insert(@@curi + 1, w2)
      end

      # Adjust window sizes and top rows.
      w.nrow = upper_nrow
      w2.toprow = w.toprow + upper_nrow + 1
      w2.nrow = lower_nrow
    else
      # The old window is the lower window.  Insert
      # the new window above it in the window list.
      @@list.insert(@@curi, w2)

      # Keep the old window as the current window.
      @@curi += 1

      # Set the new window's top row and number of rows.
      w2.toprow = w.toprow
      w2.nrow = upper_nrow
      
      # Set the old window's top row and number of rows.
      upper_nrow += 1	# skip over upper window's mode line
      w.toprow += upper_nrow
      w.nrow = lower_nrow
      line += upper_nrow
    end

    # Set the top line numbers of the two windows.
    w.line = line
    w2.line = line

    return Result::True
  end

  # Binds keys for window commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('n'), cmdptr(nextwind), "forw-window")
    k.add(Kbd.ctlx('p'), cmdptr(prevwind), "back-window")
    k.add(Kbd.ctlx('2'), cmdptr(splitwind), "split-window")
  end
end
