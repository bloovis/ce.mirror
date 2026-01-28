# The `Word` module contains some commands for dealing with words.
module Word

  extend self

  # Gets the character at the dot.
  def getc : Char
    w, b, dot, lp = E.get_context
    if dot.o == lp.text.size
      return '\n' 
    else
      return lp.text[dot.o]
    end
  end

  # Replaces the character at the dot with `c`.
  # If dot is at the end of the line, do nothing.
  def putc(c : Char)
    w, b, dot, lp = E.get_context
    text = lp.text
    lsize = text.size

    # Don't handle the perverse cases where the line is empty
    # or the dot is past the end of the line.
    return if dot.o == lsize || lsize == 0

    # Replace the line text with *c* sandwiched in between
    # the parts of the line before and after the dot.
    if dot.o == 0
      lp.text = c.to_s + text[1..]
    else
      lp.text = text[0 .. (dot.o - 1)] + c.to_s + text[dot.o + 1 ..]
    end
  end

  # Returns true if the character at the dot
  # is considered to be part of a word.
  def inword
    return getc.to_s =~ /\w/
  end

  # Commands

  # Moves the cursor backward by
  # "n" words. All of the details of motion
  # are performed by the "backchar" and "forwchar"
  # routines. Error if you try to move past the
  # start of the buffer.
  def backword(f : Bool, n : Int32, k : Int32) : Result
    return forwword(f, -n, Kbd::RANDOM) if n < 0
    if Basic.backchar(false, 1, Kbd::RANDOM) == Result::False
      return Result::False 
    end
    while n > 0
      n -= 1
      # Skip back to last character of word.
      while !inword
        if Basic.backchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end

      # Skip back past start of word.
      while inword
        if Basic.backchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end
    end
    return Basic.forwchar(false, 1,Kbd::RANDOM)
  end

  # Moves the cursor forward by
  # the specified number of words. All of the
  # motion is done by "forwchar". Error if you
  # try and move beyond the buffer's end.
  def forwword(f : Bool, n : Int32, k : Int32) : Result
    return backword(f, -n, Kbd::RANDOM) if n < 0
    while n > 0
      n -= 1
      # Skip forward to start of word.
      while !inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end

      # Skip forward to end of word.
      while inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end
    end
    return Result::True
  end

  # Moves the cursor forward by
  # the specified number of words, converting
  # any lowercase characters to upper case. Error
  # if you try to move beyond the end of the
  # buffer.
  def upperword(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::False unless Files.checkreadonly

    b = E.curw.buffer
    while n > 0
      n -= 1
      # Skip forward to start of word.
      while !inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end

      # Skip forward to end of word, converting characters
      # as we go.
      while inword
	c = getc
	if c.lowercase?
	  putc(c.upcase)
	  b.lchange
	end
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end
    end
    return Result::True
  end

  # Moves the cursor forward by
  # the specified number of words, converting
  # any uppercase characters to lower case. Error
  # if you try to move beyond the end of the
  # buffer.
  def lowerword(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::False unless Files.checkreadonly

    b = E.curw.buffer
    while n > 0
      n -= 1
      # Skip forward to start of word.
      while !inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end

      # Skip forward to end of word, converting characters
      # as we go.
      while inword
	c = getc
	if c.uppercase?
	  putc(c.downcase)
	  b.lchange
	end
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end
    end
    return Result::True
  end

  # Move the cursor forward by
  # the specified number of words. As you move
  # convert the first character of the word to upper
  # case, and subsequent characters to lower case. Error
  # if you try and move past the end of the buffer.
  def capword(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    return Result::False unless Files.checkreadonly

    b = E.curw.buffer
    while n > 0
      n -= 1
      # Skip forward to start of word.
      while !inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end

      # Get first character of word, and convert it to uppercase.
      c = getc
      if c.lowercase?
	putc(c.upcase)
	b.lchange
      end
      if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	# Hit end of buffer, return now.
	return Result::False
      end

      # Skip forward to end of word, converting characters
      # as we go.
      while inword
	c = getc
	if c.uppercase?
	  putc(c.downcase)
	  b.lchange
	end
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  return Result::False
	end
      end
    end
    return Result::True
  end

  # Kills forward by "n" words. The rules for final
  # status are now different. It is not considered an error
  # to delete fewer words than you asked. This lets you say
  # "kill lots of words" and have the command stop in a reasonable
  # way when it hits the end of the buffer.
  def delfword(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    w, b, dot, lp = E.get_context
    old_dot = dot.dup	# Save dot
    Line.kdelete	# Purge kill buffer
    size = 0
    while n > 0
      n -= 1
      # Skip forward to start of word.
      while !inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  w.dot = old_dot
	  return b_to_r(Line.delete(size, true))
	end
	size += 1
      end

      # Skip forward to end of word.
      while inword
        if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit end of buffer, return now.
	  w.dot = old_dot
	  return b_to_r(Line.delete(size, true))
	end
	size += 1
      end
    end
    w.dot = old_dot
    return b_to_r(Line.delete(size, true))
  end

  # Kills backwards by "n" words. The rules
  # for success and failure are now different, to prevent
  # strange behavior at the start of the buffer. The command
  # only fails if something goes wrong with the actual delete
  # of the characters. It is successful even if no characters
  # are deleted, or if you say delete 5 words, and there are
  # only 4 words left. I considered making the first call
  # to "backchar" special, but decided that that would just
  # be wierd. Normally this is bound to "M-Rubout" and
  # to "M-Backspace".
  def delbword(f : Bool, n : Int32, k : Int32) : Result
    return Result::False if n < 0
    w, b, dot, lp = E.get_context
    Line.kdelete	# Purge kill buffer

    # Back up one character.  If we're at the start of the buffer,
    # do nothing and return success.
    return Result::True unless Basic.backchar(false, 1, Kbd::RANDOM)

    size = 1
    fail = false
    while (n > 0) && !fail
      n -= 1
      # Skip back to end of word.
      while !inword
        if Basic.backchar(false, 1, Kbd::RANDOM) == Result::False
	  # Hit start of buffer, return now.
	  fail = true
	  break
	end
	size += 1
      end

      # Skip back to start of word.
      unless fail
	while inword
	  if Basic.backchar(false, 1, Kbd::RANDOM) == Result::False
	    # Hit start of buffer, return now.
	    fail = true
	    break
	  end
	  size += 1
	end
      end
      n = 0 if fail
    end

    # We skipped one space back past start of word, so skip
    # forward one space.
    unless fail
      if Basic.forwchar(false, 1, Kbd::RANDOM) == Result::False
	return Result::False
      end
      size -= 1
    end
    return b_to_r(Line.delete(size, true))
  end

  # Creates key bindings for all Word commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.meta('f'), cmdptr(forwword), "forw-word")
    k.add(Kbd.meta('b'), cmdptr(backword), "back-word")
    k.add(Kbd.meta('d'), cmdptr(delfword), "forw-del-word")
    k.add(Kbd.meta('d'), cmdptr(delfword), "forw-del-word")
    k.add(Kbd.meta('u'), cmdptr(upperword), "upper-word")
    k.add(Kbd.meta('l'), cmdptr(lowerword), "lower-word")
    k.add(Kbd.meta('c'), cmdptr(capword), "cap-word")
    k.add(Kbd.meta_ctrl('h'), cmdptr(delbword), "back-del-word")
  end

end
