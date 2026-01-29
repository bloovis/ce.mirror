require "./pos"

# The `Undo` class holds undo information for a buffer.
# The information consists of insert and delete records,
# plus markers for the start and end of undo groups.
# The records are stored in two stacks: an undo stack
# and a redo stack.  An undo operation pops a record
# off the undo stack, replays the operation# specified
# by the records, then pushes the record onto the redo stack.
class Undo
  enum Type
    Insert
    Delete
    StartGroup
    EndGroup
  end

  class Record
    getter kind : Undo::Type
    getter pos : Pos
    getter s : String

    def initialize(@kind, @pos, @s)
    end

    def to_s : String
      if @kind == Type::StartGroup || @kind == Type::EndGroup
	return "kind #{@kind}"
      else
	return "kind #{@kind}, pos (#{@pos.l},#{@pos.o}), s '#{@s.readable}'"
      end
    end
  end

  @undo_stack : Array(Record)
  @redo_stack : Array(Record)
  @undoing : Bool

  def initialize
    @undo_stack = [] of Record
    @redo_stack = [] of Record
    @undoing = false
  end

  def add(kind : Undo::Type, pos : Pos | Nil = nil, s : String | Nil = nil)
    # Do nothing if we're in the middle of an undo operation.
    return if @undoing

    # Clear the redo stack.
    @redo_stack = [] of Record

    # If pos and s were nil, replace them with invalid/empty values.
    if pos
      # Have to dupe it in case it changes.
      pos = pos.dup
    else
      pos = Pos.new(-1,-1)
    end
    s ||= ""

    # Push a new record onto the undo stack.
    @undo_stack.push(Record.new(kind, pos, s))
  end

  # Adds a start-group record.
  def start
    add(Type::StartGroup)
  end

  # Adds an end-group record.
  def finish
    # If the previous record was a StartGroup, the group is empty,
    # so delete it and don't add an Endgroup.
    usize = @undo_stack.size
    if usize > 0 && @undo_stack[usize - 1].kind == Type::StartGroup
      @undo_stack.pop
    else
      add(Type::EndGroup)
      print	# FIXME: debug only
    end
  end

  # Adds an insert-string record.
  def insert(pos : Pos, s : String)
    add(Type::Insert, pos, s)
  end

  # Adds a delete-string record.
  def delete(pos : Pos, s : String)
    add(Type::Delete, pos, s)
  end

  # Pops one or more undo records from the stack
  # and carry out their changes.  If the
  # first record popped is an end-group record,
  # keep popping and undoing until a start-group
  # record is found.
  def undo
    return unless u = @undo_stack.pop
    @undoing = true
    STDERR.puts "Undoing #{u.to_s}"
    @redo_stack.push(u)
    @undoing = false
  end

  def print
    STDERR.puts "Undo stack:"
    @undo_stack.each {|r| STDERR.puts "  " + r.to_s}
    STDERR.puts "Redo stack:"
    @redo_stack.each {|r| STDERR.puts "  " + r.to_s}
  end
end

{% if flag?(:TEST) %}

u = Undo.new
u.start
u.add(Undo::Type::Delete, Pos.new(1,2), "this string is being deleted")
u.add(Undo::Type::Insert, Pos.new(3,4), "this string is being added")
u.finish
u.print
u.undo
u.undo
u.print
u.add(Undo::Type::Insert, Pos.new(5,6), "another string is being added")
u.print

{% end %} # flag TEST
