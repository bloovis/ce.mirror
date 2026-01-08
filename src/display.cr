require "./tabs"
require "./terminal"
require "./window"

class Display

  property tty : Terminal

  def initialize(@tty)
  end

  def update
    Window.each do |w|
      #STDERR.puts "update: w.line #{w.line}, w.toprow #{w.toprow}, w.nrow #{w.nrow}"

      # Figure out how many lines are actually visible.
      b = w.buffer
      first = w.line
      last = [first + w.nrow, b.length].min - 1

      # Display visible lines.
      b.each_in_range(first, last) do |i, lp|
        @tty.putline(i - first + w.toprow, 0, Tabs.detab(lp.text))
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
      @tty.puts((b.flags.changed? ? "*" : " ") + "MicroEMACS #{b.name} File:#{b.filename}")
      @tty.color(Terminal::CTEXT)

     end

     # Refresh the display
     @tty.flush
   end
end
