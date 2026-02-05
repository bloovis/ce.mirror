# `Pos` represents a position in a buffer:
# a zero-based line number, and the offset within that line.
class Pos
  property l : Int32
  property o : Int32

  def initialize(l=0, o=0)
    @l = l
    @o = o
  end

  # Makes a copy of position *p*.
  def initialize(p : Pos)
    @l = p.l
    @o = p.o
  end

  # Makes a copy of this position.
  def dup
    Pos.new(self)
  end

  # Compares this position with position *p* and returns:
  # * -1 if this position is less than *p*
  # *  0 if the two positions are equal
  # * +1 if this position is greater than *p*
  def cmp(p : Pos) : Int32
    return -1 if @l < p.l
    return 1 if @l > p.l
    return -1 if @o < p.o
    return 0 if @o == p.o
    return 1
  end
end
