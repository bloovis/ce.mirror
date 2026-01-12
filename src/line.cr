require "./ll"

class Line
  include LinkedList::Node

  property text : String

  def initialize(@text : String)
  end

  def self.alloc(s : String) : Pointer(Line)
    return Pointer(Line).malloc(1) {Line.new(s)}
  end

  # Inserts the string *s* at the current location.
  # Newlines in the string do *not* cause
  # new lines to be created and inserted.  To do that,
  # call `Line.newline`.
  def self.insert(s : String)
    # Insert the string in the current line.
    w, b, dot, lp = E.get_context
    lp.text = lp.text.insert(dot.o, s)

    # Save the dot, then bump the offset in the dot.
    old_dot = Pos.new(dot.l, dot.o)
    n = s.size
    dot.o += n

    # Mark the buffer as changed.
    b.flags = b.flags | Bflags::Changed

    # Adjust mark if it is in the same line
    # and is after the old dot offset.
    mark = w.mark
    if mark.l == old_dot.l && mark.o > old_dot.o
      mark.o += n
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
