# `Search` contains routines for searching/replacing text.

enum SearchDir
  Begin
  Forw
  Back
  Prev
  Next
  Nopr
  Accm
  Regforw
  Regback
end
  
module Search

  @@pat = ""			# last search pattern
  @@dir = SearchDir::Nopr	# last search direction (no previous search)

  extend self

  # Reads a pattern and stashes it in the class variable `pat`. The "pat" is
  # not updated if the user types in an empty line. If the user typed
  # an empty line, and there is no old pattern, it is an error.
  # Display the old pattern, in the style of Jeff Lomicka. There is
  # some do-it-yourself control expansion.
  def readpattern(prompt : String) : Tuple(Result, String)
    result, pattern = Echo.reply("#{prompt} [#{@@pat}]: ", @@pat)
    if result == Result::True
      @@pat = pattern
    elsif result == Result::False && pattern.size > 0
      # User hit Enter, but wants to user the old pattern.
      result == Result::True
    end
    return {result, pattern}
  end

  # Checks if there is a match in buffer *b* at location *pos*
  # for the match strings *l*.  *lp* is a pointer to the
  # line at location *pos*.  If found, returns the position
  # of the first character past the matched string; otherwise
  # returns nil.
  def match(l : Array(String), b : Buffer, pos : Pos, lp : Pointer(Line)) : Pos | Nil
    # Make a copy of pos for use in searching.
    spos = pos.dup

    # Try each string in l.
    found = false
    l.each_with_index do |s, i|
      text = lp.text
      if s == "\n"
	# Match a newline.  Fail if we're not at the end of the line
	# or this is the last line in the buffer.
	if spos.o != text.size || lp == b.last_line
	  found = false
	  break
	end

	# Skip to the next line.
	lp = lp.next
	spos.l += 1
	spos.o = 0
	found = true
      elsif 
	# Match a normal string.
	if spos.o + s.size <= text.size && text[spos.o, s.size] == s
	  found = true
	  spos.o += s.size
	else
	  found = false
	  break
	end
      end
    end

    # If all the strings in l matched, return the position past the match.
    if found
      return spos
    else
      return nil
    end
  end

  # forwsrch does the real work of a forward search. The pattern is
  # sitting in the class variable `@@pat`. If found, dot is updated, the
  # window system is notified of the change, and TRUE is returned. If the
  # string isn't found, FALSE is returned.
  def forwsrch : Result
    w, b, dot, lp = E.get_context
    l = [] of String
    @@pat.split_lines {|s| l << s}
    return Result::False if l.size == 0

    done = false
    sdot = dot.dup
    result = Result::False
    endpos = nil
    until done
      if endpos = match(l, b, sdot, lp)
	done = true
      else
	# Skip to next character in the line.  If we're at the end of the line,
	# skip to the next line.  If we're on the last line, fail.
	if sdot.o == lp.text.size
	  if lp == b.last_line
	    done = true
	  else
	    lp = lp.next
	    sdot.l += 1
	    sdot.o = 0
	  end
	else
	  sdot.o += 1
	end
      end
    end
    if endpos
      E.curw.dot = endpos
      return Result::True
    else
      return Result::False
    end
  end

  # Performs a search of the type specified by dir.
  # If the search succeeds, return TRUE.
  # If the search fails, return FALSE.
  # If there is an error that prevents the search from being
  # performed (e.g., a regexp search when no regular expression
  # is available in regpat), return ABORT.
  def dosearch(dir : SearchDir) : Result
    case dir
    when SearchDir::Forw
      return forwsrch
    else
      Echo.puts "Search type #{dir} not implemented"
      return Result::Abort
    end
  end

  # Commands.

  # Searches again, using the same search string
  # and direction as the last search command. The direction
  # has been saved in "srch_lastdir", so you know which way
  # to go.
  def searchagain(f : Bool, n : Int32, k : Int32) : Result
    result = dosearch(@@dir)
    if result == Result::False
      Echo.puts("Not found")
    elsif result == Result::Abort
      Echo.puts("No last search")
      result == Result::False
    end
    return result
  end

  # Searches forward. Gets a search string from the user, and searches for it,
  # starting at ".". If found, "." gets moved to just after the
  # matched characters, and display does all the hard stuff.
  # If not found, it just prints a message.
  def forwsearch(f : Bool, n : Int32, k : Int32) : Result
    result, pattern = readpattern("Search")
    #Echo.puts "Result #{result}, pattern #{pattern}"
    @@dir = SearchDir::Forw
    return searchagain(f, n, k)
  end

  # Creates key bindings for all Misc commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctrl('s'), cmdptr(forwsearch), "forw-search")
    k.add(Kbd::F9, cmdptr(searchagain), "search-again")
  end
end
