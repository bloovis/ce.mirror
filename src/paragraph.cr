# The `Paragraph` module contains commands for dealing with paragraphs.
module Paragraph

  @@fillcol = 72

  # Compiled regular expression to match a line that is part
  # of a paragraph, i.e. a line that starts with zero or more
  # spaces, followed by a "word" character.
  @@regex = /^\s*\w/

  extend self

  # Returns the current paragraph fill column.
  def fillcol
    @@fillcol
  end

  # Sets the paragraph fill column to *n*.
  def fillcol=(n : Int32)
    if n > 0
      @@fillcol = n
    end
  end

  # Commands.

  # This command goes back to the beginning of the current paragraph.
  def gotobop(f : Bool, n : Int32, k : Int32) : Result
    result = TRUE	# we always return this
    return gotoeop(f, -n, Kbd::RANDOM) if n < 0
    return result if n <= 0

    w, b, dot, lp = E.get_context

    n.times do
      # Scan back looking for a line that starts with a word.
      while true
	return result if lp == b.first_line
	dot.l -= 1
	dot.o = 0
	lp = lp.previous
	break if @@regex.match(lp.text)
      end

      # Scan back until the previous line doesn't start with a word.
      while true
	break if lp == b.first_line
	prev = lp.previous
	break unless @@regex.match(prev.text)
	dot.l -= 1
	dot.o = 0
	lp = prev
      end
    end
    return result
  end

  # This command goes to the end of the current paragraph.
  def gotoeop(f : Bool, n : Int32, k : Int32) : Result
    result = TRUE	# we always return this
    return gotobop(f, -n, Kbd::RANDOM) if n < 0
    return result if n == 0

    w, b, dot, lp = E.get_context

    n.times do
      # Scan forward looking for a line that starts with a word.
      while true
	return result if lp == b.last_line
	break if @@regex.match(lp.text)
	dot.l += 1
	dot.o = 0
	lp = lp.next
      end

      # Scan forward looking for a line that doesn't start with a word.
      while true
	break if lp == b.last_line
	break unless @@regex.match(lp.text)
	dot.l += 1
	dot.o = 0
	lp = lp.next
      end
    end
    return result
  end

  # This command fills the current paragraph according to the current fill column.
  def fillpara(f : Bool, n : Int32, k : Int32) : Result
    w, b, dot, lp = E.get_context

    # Get the position of the end of the paragraph.
    gotoeop(false, 1, Kbd::RANDOM)
    finish = w.dot.dup

    # Get the position of the start of the paragraph.
    gotobop(false, 1, Kbd::RANDOM)
    start = w.dot.dup

    # Get the starting line pointer.
    r = Region.new(start, finish)
    lp = b[start.l]
    if lp.nil?
      Echo.puts("Invalid line number #{start.l}!")
      return FALSE
    end

    # Collect all the words in the region into a single array.
    a = [] of String
    l = start.l
    while true
      a.concat(lp.text.split)
      break if l == finish.l
      l += 1
      lp = lp.next
    end

    # Move to the start of the paragraph and delete the entire
    # paragraph.
    w.dot = start
    Line.delete(r.size, false)

    # This is a list of characters that, if found at the end of a word,
    # require two spaces following them.
    doubles = {'.', '?', '!'}

    # Start adding words back to the buffer, making sure each line
    # doesn't exceed the fill column size.
    buf = ""
    a.each do |s|
      if buf == ""
	space = ""
      else
	space = doubles.includes?(buf[-1]) ? "  " : " "
      end
      if buf.size + space.size + s.size > @@fillcol
	Line.insert(buf)
	Line.newline
	buf = s
      else
	buf = buf + space + s
      end
    end
    if buf != ""
      Line.insert(buf)
      Line.newline
    end

    result = TRUE
  end

  # This command sets the fill column to *n*, or if *n* is not
  # provied, sets it to the current column of the dot.
  def setfillcol(f : Bool, n : Int32, k : Int32) : Result
    Paragraph.fillcol = f ? n : Misc.getcolpos
    return TRUE
  end

  # Creates key bindings for all Paragraph commands.
  def bind_keys(k : KeyMap)
    # The key binding ESC-[ can cause problems, because it is
    # the prefix for terminal escape sequences.  Entering
    # causes a 1-second delay while Ncurses waits to
    # see if any more characters follow it.  So provide
    # an ESC-{ binding for it too.
    k.add(Kbd.meta('['), cmdptr(gotobop), "back-paragraph")
    k.add_dup(Kbd.meta('{'), "back-paragraph")

    k.add(Kbd.meta(']'), cmdptr(gotoeop), "forw-paragraph")
    k.add(Kbd.meta('j'), cmdptr(fillpara), "fill-paragraph")
    k.add(Kbd::RANDOM, cmdptr(setfillcol), "set-fill-column")
  end

end
