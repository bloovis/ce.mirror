require "./tabs"
require "./terminal"
require "./window"

class Display

  property tty : Terminal

  def initialize(@tty)
  end

  def update
    # Determine the actual screen column number of the dot.  If the column is not
    # visible, change the window's left column so that it is visible.
    w, b, dot, lp = E.get_context
    curcol = lp.text.screen_width(dot.o)
    if curcol >= @tty.ncol + w.leftcol || curcol < w.leftcol
      #STDERR.puts("Curcol #{curcol}, leftcol #{w.leftcol}, tty.ncol #{@tty.ncol}")
      w.leftcol = [curcol - (@tty.ncol // 2), 0].max
      #STDERR.puts("Changing leftcol to #{w.leftcol}")
    end

    Window.each do |w|
      #STDERR.puts "update window for buffer #{w.buffer.name}: w.line #{w.line}, w.toprow #{w.toprow}, w.nrow #{w.nrow}"

      b = w.buffer
      bsize = b.size	# number of lines in buffer

      # If the dot line is not visible, reframe the window.
      dot = w.dot
      if dot.l < w.line || dot.l >= w.line + w.nrow
	i = w.nrow // 2

	# We have set i to the row on which we want the dot
	# to be shown in the window.  Given that, figure out
	# which line should be shown at the top of the window
	w.line = dot.l - i
	if w.line < 0
	  w.line = 0
	end
      end

      # Figure out how many lines are actually visible.
      first = w.line
      last = [first + w.nrow, bsize].min - 1

      # Display visible lines.
      b.each_in_range(first, last) do |i, lp|
        line = lp.text.detab.readable
	#STDERR.puts("Line size #{line.size}, leftcol #{w.leftcol}")
	if w.leftcol >= line.size
	  line = ""
	elsif w.leftcol != 0
	  line = line[w.leftcol..]
	end
	if line.size > @tty.ncol
	  line = line[0...@tty.ncol-1] + "➤"
	end
        @tty.putline(i - first + w.toprow, 0, line)
      end

      # Fill remainder with blank lines.
      (last + 1 - first..w.nrow - 1).each do |i|
        @tty.move(i + w.toprow, 0)
        @tty.eeol
      end

      # Mode line
      @tty.move(w.toprow + w.nrow, 0)
      @tty.color(Terminal::CMODE)
      @tty.eeol
      @tty.puts((b.flags.changed? ? "*" : " ") + "CrystalEdit " +
		(b.modename == "" ? "" : ("(" + b.modename + ") ")) +
                 b.name +
		(b.filename == "" ? "" : " File:#{b.filename}"))
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
