require "./ll"

class Line
  include LinkedList::Node

  property text : String

  def initialize(@text : String)
  end

  def self.alloc(s : String) : Pointer(Line)
    return Pointer(Line).malloc(1) {Line.new(s)}
  end
end

# These hacks allows a pointer to Line have the same methods as
# the thing it points to.
struct Pointer(T)
 def text
   self.value.text
 end

 def text=(s : String)
   self.value.text = s
  end
end
