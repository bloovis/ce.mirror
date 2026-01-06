# `Pos` represents a position in a buffer:
# a zero-based line number, and the offset within that line.
class Pos
  property l : Int32
  property o : Int32

  def initialize(l=0, o=0)
    @l = l
    @o = o
  end
end
