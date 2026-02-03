# The `Paragraph` module contains commands for dealing with paragraphs.

module Paragraph

  @@fillcol = 72

  # Compiled regular expression to match a line that is part
  # of a paragraph.
  @@regex = Regex.new("^\\s*\\w")

  extend self

  def fillcol
    @@fillcol
  end

  def fillcol=(n : Int32)
    if n > 0
      @@fillcol = n
    end
  end

  # Goes back to the beginning of the current paragraph.
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

  # Goes to the end of the current paragraph.
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
  end

end
