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
  property line : Int32		# top line in the window
  property dot : Pos		# current position in buffer
  property mark : Pos		# mark position
  property savep : Pos		# saved line position for search
  property toprow : Int32	# top screen row of window
  property nrows : Int32	# number of screen rows in window
  property leftcol : Int32	# left column of window
  property force : Int32	# if non-zero, force dot to be displayed at this row
  property flags : Wflags	# flags that give hints to the display updater
  
  @@list = [] of Window		# list of all windows
  @@curi = -1			# index to @@list of current window

  def initialize(@buffer)
    # Initialize the various instance variables.
    @line = 0
    @dot = Pos.new()
    @mark = Pos.new()
    @savep = Pos.new()
    @toprow = 0
    @nrows = 0
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

  def self.current : Window
    if @@curi >= 0 && @@curi < @@list.size
      return @@list[@@curi]
    else
      raise "Invalid current window index #{@@curi}!"
    end
  end

  def self.current= (w : Window)
    i = @@list.index(w)
    if i
      @@curi = i
    else
      raise "Window #{w} is not in list!"
    end
  end

  def self.each
    @@list.each do |window|
      yield window
    end
  end

end
