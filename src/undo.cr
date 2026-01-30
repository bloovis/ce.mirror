require "./pos"
require "./util"

# The `Undo` class holds undo information for a buffer.
# The information consists of insert and delete records,
# plus markers for the start and end of undo groups.
# The records are stored in two stacks: an undo stack
# and a redo stack.  An undo operation pops a record
# off the undo stack, replays the operation# specified
# by the records, then pushes the record onto the redo stack.
class Undo
  enum Kind
    Insert
    Delete
  end

  @[Flags]
  enum Uflags
    Start
    Finish
  end

  class Record
    getter kind : Undo::Kind
    property flags : Uflags
    getter pos : Pos
    getter s : String

    def initialize(@kind, @flags, @pos, @s)
    end

    def to_s : String
      return "kind #{@kind}, flags #{flags}, pos (#{@pos.l},#{@pos.o}), s '#{@s.readable}'"
    end
  end

  property undo_stack : Array(Record)	# Stack of undo records
  property redo_stack : Array(Record)	# Stack of redo records
  property undoing : Bool		# True if we're in the middle of an undo
  @count : Int32			# Count of records seen since a group start

  def initialize
    @undo_stack = [] of Record
    @redo_stack = [] of Record
    @undoing = false
    @count = -1			# -1 means a group start hasn't been seen yet
  end

  private def add(kind : Undo::Kind, pos : Pos | Nil = nil, s : String | Nil = nil)
    # Do nothing if we're in the middle of an undo operation.
    return if @undoing

    # Clear the redo stack.
    @redo_stack = [] of Record

    # If this is the first record since a group start, mark it
    # as the start of the group.
    if @count == 0
      flags = Uflags::Start
      @count += 1
    else
      flags = Uflags::None
    end

    # If pos and s were nil, replace them with invalid/empty values.
    if pos
      # Have to dupe it in case it changes.
      pos = pos.dup
    else
      pos = Pos.new(-1,-1)
    end
    s ||= ""

    # Push a new record onto the undo stack.
    @undo_stack.push(Record.new(kind, flags, pos, s))
  end

  # Indicate that we are starting an undo group by setting
  # the record count to 0.
  def start
    @count = 0
    #STDERR.puts "undo start"
    #print
  end

  # Indicate that we are finishing an undo group by marking
  # the last record seen as the end of the group.
  def finish
    if @count > 0
      usize = @undo_stack.size
      if usize > 0	# this should always be true, but check anyway
	r = @undo_stack[usize - 1]
	r.flags = r.flags | Uflags::Finish
      end
      #print
    end
    @count = -1		# -1 means we haven't seen a group start yet
    #STDERR.puts "undo finish"
    #print
  end

  # Adds an insert-string record.
  def insert(pos : Pos, s : String)
    add(Kind::Insert, pos, s)
    #STDERR.puts "undo delete"
    #print
  end

  # Adds a delete-string record.
  def delete(pos : Pos, s : String)
    add(Kind::Delete, pos, s)
    #STDERR.puts "undo delete"
    #print
  end

  def print
    STDERR.puts "Undo stack:"
    @undo_stack.each {|r| STDERR.puts "  " + r.to_s}
    STDERR.puts "Redo stack:"
    @redo_stack.each {|r| STDERR.puts "  " + r.to_s}
  end

  # Commands.

  # Pops one or more undo records from the stack
  # and carry out their changes.  If the
  # first record popped is an end-group record,
  # keep popping and undoing until a start-group
  # record is found.
  def self.undo(f : Bool, n : Int32, k : Int32) : Result
    w = E.curw
    b = w.buffer
    u = b.undo
    u.undoing = true
    while true
      r = u.undo_stack.pop?
      if r.nil?
	Echo.puts("Undo stack is empty")
	u.undoing = false
	return Result::False
      end
      #STDERR.puts("Undoing #{r.to_s}")
      case r.kind
      when Undo::Kind::Insert
        w.dot = r.pos.dup
	Line.delete(r.s.size, false)
      when Undo::Kind::Delete
        w.dot = r.pos.dup
	Line.insertwithnl(r.s)
      end
      u.redo_stack.push(r)
      #STDERR.puts("After undoing, dot is (#{w.dot.l},#{w.dot.o}")
      break if r.flags.start?
    end
    u.undoing = false
    return Result::True
  end

  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx('u'), cmdptr(undo), "undo")
    k.add_dup(Kbd::F5, "undo")
  end

end

{% if flag?(:TEST) %}

u = Undo.new
u.start
u.delete(Pos.new(1,2), "this string is being deleted")
u.insert(Pos.new(3,4), "this string is being added")
u.insert(Pos.new(7,8), "a string at line 7")
u.finish
u.print
u.undo
u.undo
u.print
u.insert(Pos.new(5,6), "another string is being added at line 5")
u.print

{% end %} # flag TEST
