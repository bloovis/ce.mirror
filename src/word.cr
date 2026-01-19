# The `Word` module contains some commands for dealing with words.
module Word

  extend self

  # Returns TRUE if the character at offset *o* in line *lp*
  # is a character that is considered to be
  # part of a word.
  def inword
    w, b, dot, lp = E.get_context
    return false if dot.o == lp.text.size
    return lp.text[dot.o].to_s =~ /\w/
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
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.meta('d'), cmdptr(delfword), "forw-del-word")
    k.add(Kbd.meta_ctrl('h'), cmdptr(delbword), "back-del-word")
  end

end
