require "./tabs"
require "./terminal"
require "./window"

# The `Display` object is responsible for updating the screen if/when
# anything changes in the visible windows.
class Display

  # The `Terminal` object associated with this display.
  property tty : Terminal

  def initialize(@tty)
  end

  # Updates the ncurses screen with the contents of the windows, plus the mode line.
  def update
    # Determine the actual screen column number of the dot.  If the column is not
    # visible, change the window's left column so that it is visible.
    w, b, dot, lp = E.get_context
    curcol = lp.text.screen_width(dot.o)
    ttywidth = @tty.ncol
    if curcol >= w.leftcol + ttywidth || curcol < w.leftcol
      #STDERR.puts("Curcol #{curcol}, leftcol #{w.leftcol}, tty.ncol #{ttywidth}")
      w.leftcol = {curcol - (ttywidth // 2), 0}.max
      #STDERR.puts("Changing leftcol to #{w.leftcol}")
    end

    Window.each do |w|
      #STDERR.puts "update window for buffer #{w.buffer.name}: w.line #{w.line}, w.toprow #{w.toprow}, w.nrow #{w.nrow}"

      b = w.buffer

      # If the dot line is not visible, reframe the window.
      dot = w.dot
      if dot.l < w.line || dot.l >= w.line + w.nrow
	i = w.nrow // 2

	# We have set i to the row on which we want the dot
	# to be shown in the window.  Given that, figure out
	# which line should be shown at the top of the window
	w.line = b.clamp(dot.l - i)
      end

      # Figure out how many lines are actually visible.
      first = w.line
      last = b.clamp(first + w.nrow - 1)

      # Display visible lines.
      b.each_in_range(first, last) do |i, lp|
        # Remove tabs and make control characters readable.  Use ttywidth + 1 so that
	# we can tell below if the line will be too long to fit on the screen.
        line = lp.text.readable(expand: true, leftcol: w.leftcol, width: ttywidth + 1)

	# If the line won't fit on the screen, change the character at the right
	# margin to an arrow to indicate that there is more to the right.
	if line.size > ttywidth
	  line = line[0...ttywidth-1] + "➤"
	end
        @tty.putline(i - first + w.toprow, 0, line)
      end

      # Fill remainder with blank lines.
      (last + 1 - first..w.nrow - 1).each do |i|
        @tty.move(i + w.toprow, 0)
        @tty.eeol
      end

      # Construct the mode line, displaying the buffer changed flag,
      # the mode name (if non-blank), the buffer name, and the filename.
      @tty.move(w.toprow + w.nrow, 0)
      @tty.color(Terminal::CMODE)
      @tty.eeol
      modeline = String.build do |str|
        str << (b.flags.changed? ? "*" : " ")
	str << "CrystalEdit "
	if b.modename.size > 0
	  str << "(#{b.modename}) "
	end
	str << b.name
	if b.filename.size > 0
	  str << " File:#{b.filename}"
	end
      end
      @tty.puts(modeline)
      @tty.color(Terminal::CTEXT)

    end

    # Set the cursor to the corresponding screen position of the dot
    # in the current window.
    w = E.curw
    dot = w.dot
    currow = dot.l - w.line + w.toprow 
    @tty.move(currow, curcol - w.leftcol)

    # Refresh the display
    @tty.flush
  end
end
