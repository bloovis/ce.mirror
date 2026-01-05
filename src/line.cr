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
