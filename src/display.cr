require "./tabs"
require "./terminal"
require "./window"

class Display

  property tty : Terminal

  def initialize(@tty)
  end

  def update
    Window.each do |w|
      # Figure out how many lines are actually visible.
      b = w.buffer
      first = w.line
      last = [first + w.nrows, b.length].min - 1

      # Display visible lines.
      b.each_in_range(first, last) do |i, lp|
        @tty.putline(i - first + w.toprow, 0, Tabs.detab(lp.text))
      end

      # Fill remainder with blank lines.
      (last + 1 - first..w.nrows - 1).each do |i|
        @tty.move(i + w.toprow, 0)
        @tty.eeol
      end

      # Mode line
      @tty.move(@tty.nrow - 2, 0)
      @tty.color(Terminal::CMODE)
      @tty.eeol
      @tty.puts(" MicroEMACS #{b.name} File:#{b.filename}")
      @tty.color(Terminal::CTEXT)

     end

     # Refresh the display
     @tty.flush
   end
end
