require "./ll"

# Application-specific extensions to the `String` class.
class String
  # Splits a string into lines, and passes each line to the block.
  # It passes newlines (\n) as separate one-character strings, which
  # allows the block to handle them in a special way.  This also ensures
  # the correct behavior if the last line in the string does not
  # end in a newline.
  def split_lines(&b)
    offset = 0
    len = self.size
    while offset < len
      i = self.index('\n', offset)
      if i.nil?
	yield self[offset, len - offset]
	offset = len
      else
	yield self[offset, i - offset]
	yield "\n"
	offset = i + 1
      end
    end
  end
end

# The `Line` class is an object that contains a text string, and next and previous links
# for inserting the line on a doubly-linked list.  The `Buffer` class holds
# this linked list.
#
# `Line` contains class methods for inserting and deleting text or newlines.
# These class methods use various "global" variables in the `E` class, such as
# the current window and buffer, to determine which lines are affected by
# these operations.
#
# `Line` also contains class methods for dealing with the "kill" buffer, which
# is a string containg text that has been deleted, and which can be "yanked" back
# into existence.
class Line

  # The kill buffer.
  @@kbuf = ""

  include LinkedList::Node

  property text : String

  def initialize(@text : String)
  end

  # Allocates a new Line object.
  def self.alloc(s : String) : Pointer(Line)
    return Pointer(Line).malloc(1) {Line.new(s)}
  end

  # Inserts a newline into the buffer at the current location of dot
  # in the current window, by splitting the current line into
  # two lines.
  def self.newline : Bool
    return false unless Files.checkreadonly

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
    b.lchange

    # Adjust dot and mark in all windows that have the same buffer.
    oldpos = dot.dup
    Window.each do |w1|
      if w1.buffer == b
	[w1.dot, w1.mark].each do |pos|
	  if pos.l == oldpos.l && pos.o >= oldpos.o
	    pos.o -= oldpos.o
	    pos.l += 1
	  elsif pos.l > oldpos.l
	    pos.l += 1
	  end
	end
      end
    end
    return true
  end

  # Inserts the string *s* in the current line at the current dot location.
  # Newline characters ('\n') in the string do *not* cause
  # new lines to be created and inserted.  To do that,
  # call `Line.newline`.
  def self.insert(s : String) : Bool
    return false unless Files.checkreadonly

    # Number of characters being inserted.
    n = s.size

    # Insert the string in the current line.
    w, b, dot, lp = E.get_context
    lp.text = lp.text.insert(dot.o, s)

    # Mark the buffer as changed.
    b.lchange

    # Adjust dot and mark in all windows that have the same buffer.
    oldpos = dot.dup
    Window.each do |w1|
      if w1.buffer == b
	dot = w1.dot
	if dot.l == oldpos.l && (w1 == w || dot.o > oldpos.o)
	  dot.o += n
	end
	mark = w1.mark
	if mark.l == oldpos.l && mark.o > oldpos.o
	  mark.o += n
	end
      end
    end
    return true
  end

  # Deletes a newline. Joins the current line
  # with the next line. If the next line is the magic
  # header line always return TRUE; merging the last line
  # with the header line can be thought of as always being a
  # successful operation, even if nothing is done, and this makes
  # the kill buffer work "right". Easy cases can be done by
  # shuffling data around. Hard cases require that lines be moved
  # about in memory. Return FALSE on error and TRUE if all
  # looks ok. Called by `Line.delete` only.
  def self.delnewline : Bool
    w, b, dot, prevl = E.get_context

    # Do nothing at the buffer end.
    if prevl == b.last_line
      #STDERR.puts "Line.delnewline: on last line"
      return true
    end

    # Mark the buffer as changed.
    b.lchange

    # Append the next line to the current line.
    prevsize = prevl.text.size
    nextl = prevl.next
    prevl.text = prevl.text + nextl.text
    #STDERR.puts "Line.delnewline: joined line = '#{prevl.text}'"

    # Unlink the next line.
    b.delete(nextl)

    # Adjust dot and mark in all windows that have the same buffer.
    oldpos = dot.dup
    Window.each do |w1|
      if w1.buffer == b
	[w1.dot, w1.mark].each do |pos|
	  if pos.l == oldpos.l + 1
	    # This position is in the line that got deleted.
	    pos.o += prevsize
	    pos.l -= 1
	  elsif pos.l > oldpos.l
	    # This position is somewhere after the line that got deleted.
	    pos.l -= 1
	  end
	end
      end
    end
    return true
  end

  # Deletes "n" characters, starting at dot.
  #
  # It understands how do deal
  # with end of lines, etc. It returns TRUE if all
  # of the characters were deleted, and FALSE if
  # they were not (because dot ran into the end of
  # the buffer. The "kflag" is TRUE if the text
  # should be put in the kill buffer.
  def self.delete(n : Int32, kflag : Bool) : Bool
    #STDERR.puts "Line.delete: n #{n}, kflag #{kflag}"

    if n < 0
      Echo.puts("Region is too large (negative)")
      return false
    end
    return false unless Files.checkreadonly
    while n > 0
      # This is inefficient.  We should be able to keep updating
      # lp using lp.next.
      w, b, dot, lp = E.get_context
      #STDERR.puts "Line.delete: n #{n}, dot (#{dot.l},#{dot.o}), line '#{lp.text}'"

      # Calculate how many characters to delete in this line.
      text = lp.text
      lsize = text.size
      chars = [lsize - dot.o, n].min
      if chars == 0
	# If we're at the end of the line, merge this line
	# with the next line.
	return false unless Line.delnewline
	if kflag
	  return false unless Line.kinsert("\n")
	end
	n -= 1
      else
	# Mark the buffer as changed.
	b.lchange

	# Remove nchars characters from this line.
	right = dot.o + chars
	if kflag
	  return false unless Line.kinsert(text[dot.o, chars])
	end
	lp.text = text[0, dot.o] + text[right, lsize - right]
	#STDERR.puts "line with #{chars} chars removed: '#{lp.text}'"
	n -= chars

	# Adjust dot and mark in all windows that have the same buffer.
	oldpos = dot.dup
	Window.each do |w1|
	  if w1.buffer == b
	    [w1.dot, w1.mark].each do |pos|
	      if pos.l == oldpos.l && pos.o >= oldpos.o
		pos.o = [pos.o - chars, oldpos.o].max
	      end
	    end
	  end
	end	# Window.each
      end

      # Stop if we've hit the end of the buffer.
      break if lp == b.last_line
    end
    return true
  end

  # Deletes all the text in the kill buffer.
  def self.kdelete
    E.thisflag = E.thisflag | Eflags::Kill	# This is a kill command
    if E.lastflag.kill?				# Last command was kill?
      return					# Don't purge yet
    end
    @@kbuf = ""
  end

  # Adds a string of characters to the kill buffer.
  def self.kinsert(s : String)
    #STDERR.puts "kinsert: adding #{s} to #{@@kbuf}"
    @@kbuf = @@kbuf + s
  end

  # Passes each line in the kill buffer to the passed-in block.
  # It passes newlines (\n) in the kill buffer as
  # separate single-character strings, not part of any other line.
  def self.keach
    @@kbuf.split_lines {|s| yield s}
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
