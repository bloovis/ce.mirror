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
  getter   buffer : Buffer	# buffer attached to this window
  property line : Int32		# buffer line number of the window's top line
  property dot : Pos		# current cursor position in buffer
  property mark : Pos		# mark position
  property udot : Pos		# special undo position
  property savep : Pos		# saved line position for search
  property toprow : Int32	# top screen row of window
  property nrow : Int32		# number of screen rows in window
  property leftcol : Int32	# left column of window
  property force : Int32	# if non-zero, force dot to be displayed at this row
  property flags : Wflags	# flags that give hints to the display updater

  @@list = [] of Window		# list of all windows
  @@curi = -1			# index to @@list of current window

  def initialize(@buffer)
    # Initialize the various instance variables.
    @line = 0
    @dot = Pos.new()
    @mark = Pos.new(-1, 0)	# -1 means not set
    @udot = Pos.new(-1, 0)	# -1 means not set
    @savep = Pos.new()
    @toprow = 0
    @nrow = 0
    @leftcol = 0
    @force = 0
    @flags = Wflags::None

    # Bump the window count of the buffer.
    #STDERR.puts("Window.initialize: calling add_wind(1)")
    add_wind(1)

    #STDERR.puts "Added window for buffer #{@buffer.name}, toprow #{@toprow}, nrow #{@nrow}"
  end

  # Sets the buffer *b* associated with this window.  First decrement
  # the window count of the old buffer.  Then if *b* is not nil,
  # associate it with the window and increment its window count.
  def buffer=(b : Buffer | Nil)
    if b && (b == @buffer)
       #STDERR.puts("buffer=: setting buffer to old buffer #{b.name}!")
    end
    #STDERR.puts("buffer=: before decrement, old buffer #{@buffer.name}, nwind #{@buffer.nwind}")
    add_wind(-1)
    #STDERR.puts("buffer=: after decrement, old buffer #{@buffer.name}, nwind #{@buffer.nwind}")
    if b
      @buffer = b
      add_wind(1)
      #STDERR.puts("buffer=: new buffer #{@buffer.name}, nwind #{@buffer.nwind}")
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
  private def add_wind(n : Int32)
    b = @buffer
    #STDERR.puts("add_wind: n #{n}, buffer #{b.name}, nwind #{b.nwind}")
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
    E.oldbufn = @buffer.name

    # Set the new current buffer and increment its window count.
    #STDERR.puts("usebuf: old buffer #{@buffer.name}, new buffer #{b.name}")
    self.buffer = b

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

  # Append the window *w* to the list of windows.  
  # If this is the first window, make it the current one.
  def self.add_to_list(w : Window)
    if @@curi == -1
      @@curi = 0
    end
    @@list << w
  end


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

  # Picks a window for a pop-up.
  # Splits the screen if there is only
  # one window. Picks the uppermost window that
  # isn't the current window. An LRU algorithm
  # might be better. Returns a pointer, or
  # NULL on error.
  def self.popup : Window | Nil
    # If there's only one window, split it.
    if @@list.size == 1
      if splitwind(false, 0, Kbd::RANDOM) == Result:False
	return nil
      end
    end

    # Find the first non-current window.
    Window.each do |w|
      if w != E.curw
	#STDERR.puts("popup: toprow #{w.toprow}, nrow #{w.nrow}, line #{w.line}")
	return w
      end
    end
    return nil	# Should never get here
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
    #STDERR.puts("splitwind: splitting window with buffer #{w.buffer.name}")
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

  # This command makes the current
  # window the only window on the screen.
  # Try to set the framing
  # so that "." does not have to move on
  # the display. Some care has to be taken
  # to keep the values of dot and mark
  # in the buffer structures right if the
  # destruction of a window makes a buffer
  # become undisplayed.
  def self.onlywind(f : Bool, n : Int32, k : Int32) : Result
    #STDERR.puts("onlywind: buffer #{E.curb.name}")
    # Decrement the window count for each buffer owned
    # by a non-current window.
    Window.each do |w|
      #STDERR.puts("onlywind: checking window with buffer #{w.buffer.name}")
      if w != @@list[@@curi]
	# Break the association the window (which is about to be
	# discarded) and its buffer.
	#STDERR.puts("onlywind: decrementing nwind for #{w.buffer.name}")
	w.buffer = nil
      end
    end

    # Replace the window list with the current window.
    w = @@list[@@curi]
    @@list = [w]
    @@curi = 0

    # Reframe the window to avoid moving dot, if possible.
    if w.dot.l - w.toprow < 0
      w.line = 0
    else
      w.line -= w.toprow
    end
    w.toprow = 0
    w.nrow = E.tty.nrow - 2	# 2 = mode line + echo line
    return Result::True
  end

  # Adjusts windows so that they all have approximately
  # the same height.
  def self.balancewindows(f : Bool, n : Int32, k : Int32) : Result
    nwind = @@list.size
    if nwind == 1
      Echo.puts("Only one window")
      return Result::False
    end
    toprow = 0
    size = (E.tty.nrow // nwind) - 1
    @@list.each_with_index do |w, i|
      if i == nwind - 1
	size = E.tty.nrow - toprow - 2
      end
      if size < w.nrow
	# Shrink this window.  Move the top line number down
	# by the amount being shrunk to avoid scrolling the window.
	n = w.nrow - size	# No. of rows to remove
	w.line = [w.line + n, w.buffer.size - 1].min
      end
      w.toprow = toprow
      w.nrow = size
      toprow += size + 1
    end
    return Result::True
  end

  # Refreshes the display. A call is made to the
  # `getsize` method in the terminal handler, which tries
  # to reset "nrow" and "ncol". If the display
  # changed size, arrange that everything is redone, then
  # call `update` to fix the display. We do this so the
  # new size can be displayed. In the normal case the
  # call to `update` in event loop refreshes the screen,
  # and all of the windows need not be recomputed.
  # Note that when you get to the "display unusable"
  # message, the screen will be messed up. If you make
  # the window bigger again, and send another command,
  # everything will get fixed!
  def self.refreshscreen(f : Bool, n : Int32, k : Int32) : Result
    tty = E.tty
    oldnrow = tty.nrow
    oldncol = tty.ncol
    E.tty.getsize
    if tty.nrow != oldnrow || tty.ncol != oldncol
      # Find the bottom window and see if it can be resized
      # without making it too small.
      w = @@list[@@list.size - 1]
      if tty.nrow < w.toprow + 3
	Echo.puts("Display unusable")
	return Result::False
      end
      w.nrow = tty.nrow - w.toprow - 2
      E.disp.update
      Echo.puts("[New size #{tty.nrow} by #{tty.ncol}]")
    else
      E.disp.update
    end
    return Result::True
  end

  # Binds keys for window commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('n'), cmdptr(nextwind), "forw-window")
    k.add(Kbd.ctlx('p'), cmdptr(prevwind), "back-window")
    k.add(Kbd.ctlx('2'), cmdptr(splitwind), "split-window")
    k.add(Kbd.ctlx('1'), cmdptr(onlywind), "only-window")
    k.add(Kbd.ctlx('+'), cmdptr(balancewindows), "balance-windows")
    k.add(Kbd.ctrl('l'), cmdptr(refreshscreen), "refresh")
  end
end
