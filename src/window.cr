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

    # Add this window to the global list.
    @@list << self

    # If this is the first window, make it the current one.
    if @@curi == -1
      @@curi = 0
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

  # Binds keys for window commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('n'), cmdptr(nextwind), "forw-window")
    k.add(Kbd.ctlx('p'), cmdptr(prevwind), "back-window")
  end
end
