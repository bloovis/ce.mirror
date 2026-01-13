require "./ll"

class Line
  include LinkedList::Node

  property text : String

  def initialize(@text : String)
  end

  def self.alloc(s : String) : Pointer(Line)
    return Pointer(Line).malloc(1) {Line.new(s)}
  end

  # Inserts a newline into the buffer at the current location of dot
  # in the current window, by splitting the current line into
  # two lines.
  def self.newline
    # Get the current line.
    w, b, dot, lp = E.get_context

    # Create a new line and populate it with the
    # portion of the old line that is being split off,
    # and shrink the old line to the portion that is
    # not being split off.
    text = lp.text
    n = text.size
    if dot.o == 0
      # At beginning of the line, copy the current line
      # in its entirety to the new line, and blank the current line.
      lp1 = Line.alloc(text)
      lp.text = ""
    elsif dot.o == n
      # At the end of the line, leave the current line as is
      # and make a new blank line.
      lp1 = Line.alloc("")
    else
      # Split the current line into two pieces
      lp1 = Line.alloc(text[dot.o .. -1])
      lp.text = text[0 .. dot.o - 1]
    end

    # Insert the new line to the old one.
    b.insert_after(lp, lp1)

    # Mark the buffer as changed.
    b.flags = b.flags | Bflags::Changed

    # Adjust dot and mark in all windows that have the same buffer.
    old_dot = Pos.new(dot.l, dot.o)
    Window.each do |w1|
      if w1.buffer == b
	[w1.dot, w1.mark].each do |pos|
	  if pos.l == old_dot.l && pos.o >= old_dot.o
	    pos.o -= old_dot.o
	    pos.l += 1
	  elsif pos.l > old_dot.l
	    pos.l += 1
	  end
	end
      end
    end
  end

  # Inserts the string *s* in the current line at the current dot location.
  # Newline characters ('\n') in the string do *not* cause
  # new lines to be created and inserted.  To do that,
  # call `Line.newline`.
  def self.insert(s : String)
    # Number of characters being inserted.
    n = s.size

    # Insert the string in the current line.
    w, b, dot, lp = E.get_context
    lp.text = lp.text.insert(dot.o, s)

    # Mark the buffer as changed.
    b.flags = b.flags | Bflags::Changed

    # Adjust dot and mark in all windows that have the same buffer.
    old_dot = Pos.new(dot.l, dot.o)
    Window.each do |w1|
      if w1.buffer == b
	dot = w1.dot
	if dot.l == old_dot.l && (w1 == w || dot.o > old_dot.o)
	  dot.o += n
	end
	mark = w1.mark
	if mark.l == old_dot.l && mark.o > old_dot.o
	  mark.o += n
	end
      end
    end
  end

end

# These hacks allows a pointer to Line have the some of the same methods as
# the thing it points to.
struct Pointer(T)
 def text : String
   self.value.text
 end

 def text=(s : String)
   self.value.text = s
 end

 def next : Pointer(T)
   self.value.next
 end

 def previous : Pointer(T)
   self.value.previous
 end
end
