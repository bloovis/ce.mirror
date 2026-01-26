# `Search` contains routines for searching/replacing text.

module Search

  # Current search direction/type.
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

  @@pat = ""			# last search pattern
  @@dir = SearchDir::Nopr	# last search direction (no previous search)
  @@regpat : Regex | Nil	# last compiled regex pattern
  @@regmatch : Regex::MatchData | Nil	# result of last regex match
  @@casefold = true		# if true, ignore case in non-regex searches

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
      result = Result::True
    end
    return {result, pattern}
  end

  # This routine does the real work of a regular expression
  # forward search. The pattern is sitting in the class
  # variable `@@pat`, and the compiled pattern is in `@@regpat`.
  # If found, dot is updated, the window system
  # is notified of the change, and TRUE is returned. If the
  # string isn't found, FALSE is returned.
  #
  # A copy of the line where the pattern was found is kept
  # around until the next search is performed, so that that
  # pointers to the pattern in regpat will still be valid
  # if regsub is called.  The copy is freed on the next search.
  def doregsrch(dir : SearchDir) : Result
    w, b, dot, lp = E.get_context
    forward = dir == SearchDir::Regforw

    # Save dot in case the search fails.
    olddot = dot.dup

    while true
      # If searching forward, copy the part of the line after the dot;
      # otherwise copy the part of the line before the dot.
      if forward
	s = lp.text[dot.o..]
      else
	s = lp.text[0, dot.o]
      end

      # Test the line portion against the pattern.
      break unless regex = @@regpat
      if m = regex.match(s)
	# There is a match.  If searching forward, put the dot
	# after the matched string; otherwise put the dot before.
	@@regmatch = m
	if forward
	  dot.o += m.end(0)
	else
	  dot.o = m.begin(0)
	end
	w.dot = dot
	return Result::True
      end
      
      # Try again in next/previous line.
      if forward
	break if lp == b.last_line
	lp = lp.next
	dot.l += 1
	dot.o = 0
      else
	break if lp == b.first_line
	lp = lp.previous
	dot.l -= 1
	dot.o = lp.text.size
      end
    end

    # If we got here, the search failed.  Restore dot.
    w.dot = olddot
    return Result::False
  end

  # Search forward using regular expression.
  # Get a search string, which must be a regular expression, from the user,
  # and search for it, starting at ".". If found, "." gets moved to just
  # after the matched characters, and display does all the hard stuff.
  # If not found, it just prints a message.
  def regsearch(prompt : String, dir : SearchDir) : Result
    result, pattern = readpattern(prompt)
    return result if result != Result::True
    @@dir = dir

    # Compile the pattern into a regular expression.
    if Regex.error?(pattern)
      Echo.puts "Invalid regular expression"
      return Result::False
    end
    @@regpat = Regex.new(pattern)

    # Search the current buffer for the pattern.
    result = doregsrch(dir)
    Echo.puts "Not found" if result == Result::False
    return result
  end

  # Checks if there is a match in buffer *b* at location *pos*
  # for the match strings *pats*.  *lp* is a pointer to the
  # line at location *pos*.  If found, returns the position
  # of the first character past the matched string; otherwise
  # returns nil.
  def match(pats : Array(String), b : Buffer, pos : Pos, lp : Pointer(Line)) : Pos | Nil
    # Make a copy of pos for use in searching.
    spos = pos.dup

    # Try each string in pats.
    found = false
    pats.each_with_index do |s, i|
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
	if spos.o + s.size <= text.size &&
	   text[spos.o, s.size].compare(s, case_insensitive: @@casefold) == 0
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

  # backsrch does the real work of a backward search. The pattern is
  # sitting in the class variable `@@pat`. If found, dot is updated, the
  # window system is notified of the change, and TRUE is returned. If the
  # string isn't found, FALSE is returned.
  def backsrch : Result
    w, b, dot, lp = E.get_context
    pats = [] of String
    @@pat.split_lines {|s| pats << s}
    return Result::False if pats.size == 0

    # olddot saves the dot in case we have to restore it when `match` fails.
    # endpos is the ending position returned by `match` when it succeeds.
    olddot = dot.dup
    endpos = nil

    # We first have to skip backwards by the size of the pattern
    # before we can start calling `match`.
    skip = @@pat.size

    while true
      if skip > 0
	skip -= 1
      else
	if endpos = match(pats, b, dot, lp)
	  # Found a match.  End the loop.
	  break
	end
      end

      # Skip to previous character in the line.  If we're at the
      # start of the line, skip to the previous line, but fail
      # if we're on the first line.
      if dot.o == 0
	if lp == b.first_line
	  # Tried to back up past the first line.  End the loop.
	  break
	else
	  # Move to the previous character in the line.
	  lp = lp.previous
	  dot.l -= 1
	  dot.o = lp.text.size
	end
      else
	dot.o -= 1
      end
    end
    if endpos
      E.curw.dot = dot
      return Result::True
    else
      E.curw.dot = olddot
      return Result::False
    end
  end

  # forwsrch does the real work of a forward search. The pattern is
  # sitting in the class variable `@@pat`. If found, dot is updated, the
  # window system is notified of the change, and TRUE is returned. If the
  # string isn't found, FALSE is returned.
  def forwsrch : Result
    w, b, dot, lp = E.get_context
    pats = [] of String
    @@pat.split_lines {|s| pats << s}
    return Result::False if pats.size == 0

    # sdot is a copy of dot, and will be used to move through
    # the buffer as we call `match`.  endpos is the ending position
    # returned by `match` when it succeeds.
    sdot = dot.dup
    endpos = nil

    while true
      if endpos = match(pats, b, sdot, lp)
	# Found a match.  End the loop.
	break
      else
	# Skip to next character in the line.  If we're at the end of the
	# line, skip to the next line, but fail if we're on the last line.
	if sdot.o == lp.text.size
	  if lp == b.last_line
	    # Tried to go past the last line.  End the loop.
	    break
	  else
	    # Move to the next character in the line.
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
    when SearchDir::Back
      return backsrch
    when SearchDir::Regforw, SearchDir::Regback
      if @@regpat
	return doregsrch(dir)
      else
	return Result::Abort
      end
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
    return result if result != Result::True
    #Echo.puts "Result #{result}, pattern #{pattern}"
    @@dir = SearchDir::Forw
    return searchagain(f, n, k)
  end

  # Searches backward. Gets a search string from the user, and searches for it,
  # starting at ".". If found, "." gets moved to just after the
  # matched characters, and display does all the hard stuff.
  # If not found, it just prints a message.
  def backsearch(f : Bool, n : Int32, k : Int32) : Result
    result, pattern = readpattern("Reverse search")
    return result if result != Result::True
    @@dir = SearchDir::Back
    return searchagain(f, n, k)
  end

  # Searches forwards using a regular expression.
  # Gets a search string, which must be a regular expression, from the user,
  # and search for it, starting at ".". If found, "." is left pointing
  # after the last character of the string that was matched.
  def forwregsearch(f : Bool, n : Int32, k : Int32) : Result
    return regsearch("Regexp-search", SearchDir::Regforw)
  end

  # Searches backwards using a regular expression.
  # Gets a search string, which must be a regular expression, from the user,
  # and search for it, starting at ".". If found, "." is left pointing
  # at the first character of the string that was matched.
  def backregsearch(f : Bool, n : Int32, k : Int32) : Result
    return regsearch("Reverse regexp-search", SearchDir::Regback)
  end

  # Determines the replacement string for the search of type *dir* just
  # completed, and the size of the string being replaced. For normal searches,
  # the replacement will simply be *news*, and the replacement size
  # will the size of the search pattern. For regex searches, the replacement
  # string and the size of the string it replaces will be determined
  # from the match data.
  def getrepl(dir : SearchDir, news : String) : Tuple(String, Int32)
    if dir == SearchDir::Regforw || dir == SearchDir::Regback
      m = @@regmatch
      raise "No match data in getrepl!" unless m
      r = @@regpat
      raise "No regex in getrepl!" unless r
      plen = m.end(0) - m.begin(0)
      repl = m[0].gsub(r, news)
    else
      repl = news
      plen = @@pat.size
    end
    return {repl, plen}
  end

  # Helper function for all search and replace functions:
  #   If query is true, prompts the user for each replacement:
  #     A space or a comma replaces the string, a period replaces and quits,
  #	an n doesn't replace, a C-G quits.
  #   If `query` is false, replace all strings with no prompting.
  #   The `f` parameter is a case-fold hack flag, passed to Line.replace.
  #   The `dir` parameter indicates the kind of operation (normal
  #     or regular expression).
  def searchandreplace(f : Bool, query : Bool, dir : SearchDir) : Result
    if dir == SearchDir::Regforw || dir == SearchDir::Regback
      oldprompt = "Regexp"
      newprompt = "Replacement: "
    else
      oldprompt = "Old string"
      newprompt = "New string: "
    end

    # Prompt the user for the pattern to search for,
    # and for the replacement string.
    result, pattern = readpattern(oldprompt)
    return result if result != Result::True
    result, news = Echo.reply(newprompt, nil)
    return result if result == Result::Abort

    # If this is a regex search, compile the pattern.
    if dir == SearchDir::Regforw || dir == SearchDir::Regback
      if Regex.error?(pattern)
	Echo.puts "Invalid regular expression"
	return Result::False
      end
      @@regpat = Regex.new(pattern)
    end

    Echo.puts("[Query replace: \"#{pattern}\" -> \"#{news}\"]") if query

    # Save the current position so that we can restore it later.
    olddot = E.curw.dot.dup

    # Search forward repeatedly, checking each time whether to insert
    # or not.  The "!" case makes the check always true.
    ctrl_g = 'G' - '@'.ord
    rcnt = 0
    while dosearch(dir) == Result::True
      if query
	E.disp.update  # if !inprof
	c = E.kbd.getinp.chr
      else
	c = '!'
      end
      case c
      when ' ', ',', 'y', 'Y', '.', '!'
        # Set the replacement string to `repl` and the size of the string
	# it replaces to `plen`.
	# from the MatchData.
        repl, plen = getrepl(dir, news)
	rcnt += 1
	return Result::False unless Line.replace(plen, repl)
	break if c == '.'
      when ctrl_g
        ctrlg(false, 0, Kbd::RANDOM)
	break
      when 'n'
        next
      else
	Echo.puts("<SP>[,Yy] replace, [.] rep-end, [n] don't, [!] repl rest [C-G] quit")
      end
    end
    E.curw.dot = olddot
    E.disp.update  # if !inprof
    if rcnt == 0
      Echo.puts("No replacements done")
    elsif rcnt == 1
      Echo.puts("[1 replacement done]")
    else
      Echo.puts("[#{rcnt} replacements done]")
    end
    return Result::True
  end

  # Replace-string function.  This is the same as query-replace,
  # with the difference that it does not prompt for confirmation
  # on each string.
  def replstring(f : Bool, n : Int32, k : Int32) : Result
    return searchandreplace(f, false, SearchDir::Forw)
  end

  # Replaces strings selectively.  Does a search and replace operation.
  # A space or a comma replaces the string, a period replaces and quits,
  # an n doesn't replace, a C-G quits.  If an argument is given,
  # don't query, just do all replacements.
  def queryrepl(f : Bool, n : Int32, k : Int32) : Result
    return searchandreplace(f, true, SearchDir::Forw)
  end

  # Replaces strings unconditionally, using a regular expression as the pattern
  # and a regular expression subsitution string as the replacement.
  # Otherwise similar to replace-string.
  def regrepl(f : Bool, n : Int32, k : Int32) : Result
    return searchandreplace(f, false, SearchDir::Regforw)
  end

  # Replaces strings selectively, using a regular expression as the pattern
  # and a regular expression subsitution string as the replacement.
  # Otherwise similar to query-replace.
  def regqueryrepl(f : Bool, n : Int32, k : Int32) : Result
    return searchandreplace(f, true, SearchDir::Regforw)
  end

  # Sets the casefold flag according to the numeric argument.
  # If zero, searches do not fold case (i.e. searches
  # will be exact).  If non-zero, searches will fold case (i.e.
  # upper case letters match their corresponding lower case letters).
  # If no argument was supplied, toggles the casefold flag.
  def foldcase(f : Bool, n : Int32, k : Int32) : Result
    @@casefold = f ? n != 0 : !@@casefold
    Echo.puts("[Case folding now " + (@@casefold ? "ON" : "OFF") + "]")
    return Result::True
  end

  # The following code and tables for the searchparen command
  # were written in C by Walter Bright for MicroEMACS.  I have translated
  # them into Crystal.

  # State transition table indexes for searchparen command.
  enum Trans
    Bslash
    Fslash
    Quote
    Dquote
    Star
    Nl
    Other
    Ignore
  end

  # Current state.
  @@state = 0

  # Forward state diagram.
  FORWARD_TRANS = [
  # bs  fsl quo dqu sta nl  oth ign
   [0,  1,  4,  6,  0,  0,  0,  0], # 0: normal
   [0,  8,  4,  6,  2,  0,  0,  0], # 1: normal seen /
   [2,  2,  2,  2,  3,  2,  2,  1], # 2: comment
   [2,  0,  2,  2,  3,  2,  2,  1], # 3: comment seen *
   [5,  4,  0,  4,  4,  0,  4,  1], # 4: quote 
   [4,  4,  4,  4,  4,  4,  4,  1], # 5: quote seen \
   [7,  6,  6,  0,  6,  0,  6,  1], # 6: string
   [6,  6,  6,  6,  6,  6,  6,  1], # 7: string seen \
   [8,  8,  8,  8,  8,  0,  8,  1]  # 8: C++ comment
  ]

  # Backwards state diagram.
  BACKWARDS_TRANS = [
  # bsl fsl quo dqu sta nl  oth ign
   [0,  1,  4,  6,  0,  0,  0,  0], # 0: normal
   [0,  1,  4,  6,  2,  0,  0,  0], # 1: normal seen /
   [2,  2,  2,  2,  3,  2,  2,  1], # 2: comment
   [2,  0,  2,  2,  3,  2,  2,  1], # 3: comment seen *
   [4,  4,  5,  4,  4,  5,  4,  1], # 4: quote
   [4,  0,  0,  0,  0,  0,  0,  0], # 5: quote seen end
   [6,  6,  6,  7,  6,  7,  6,  1], # 6: string
   [6,  0,  0,  0,  0,  0,  0,  0]  # 7: string seen end
  ]

  BRACKET = [
      ['(', ')'], ['<', '>'], ['[', ']'], ['{', '}']
  ]

  # Sets the new state based on the character 'ch',
  # and returns true if we are ignoring characters
  # in the old state.
  def searchignore(ch : Char, forward : Bool) : Bool
    lss = @@state	# local search state

    if forward
      trans = FORWARD_TRANS
    else
      trans = BACKWARDS_TRANS
    end

    tr = case ch
    when '\\' then Trans::Bslash
    when '/'  then Trans::Fslash
    when '\'' then Trans::Quote
    when '"'  then Trans::Dquote
    when '*'  then Trans::Star
    when '\n' then Trans::Nl
    else           Trans::Other
    end
    @@state = trans[lss][tr.to_i]
    return trans[lss][Trans::Ignore.to_i] != 0
  end

  # Searches for a matching character: a paren or bracket.
  def searchparen(f : Bool, n : Int32, k : Int32) : Result
    # Examine the character at the dot to determine whether to
    # search forward or backwards.
    w, b, dot, lp = E.get_context

    # The character at the dot is the opening bracket, i.e.,
    # if we see this character again, it will increment
    # the bracket nesting count (hence the name chINC).
    if dot.o == lp.text.size
      chinc = '\n'
    else
      chinc = lp.text[dot.o]
    end
    olddot = dot.dup	# save dot so we can restore it if necessary

    forward = true	# Assume search forward
    chdec = chinc	# character that decrements the nesting count

    # See whether the current character is a starting
    # or ending bracket, and set the direction and the
    # the ending bracket character that decrement the nesting count.
    BRACKET.each do |pair|
      if pair[0] == chinc
	chdec = pair[1]
	break
      elsif pair[1] == chinc
        chdec = pair[0]
	forward = false
	break
      end
    end

    @@state = 0	# normal state
    count = 0	# bracket nesting count

    # Scan for a matching character or bracket.
    while true
      if forward
	# Move forward by one space.
	if dot.o == lp.text.size
	  break if lp == b.last_line
	  lp = lp.next
	  dot.l += 1
	  dot.o = 0
	else
	  dot.o += 1
	end
      else
	# Move backwards by one space.
	if dot.o == 0
	  break if lp == b.first_line
	  lp = lp.previous
	  dot.l -= 1
	  dot.o = lp.text.size
	else
	  dot.o -= 1
	end
      end

      # Examine the character at the dot.
      if dot.o == lp.text.size
	ch = '\n'
      else
	ch = lp.text[dot.o]
      end

      # Set the new state based on the character at the dot.
      # If we are not ignoring characters, check if the
      # character matches the bracket we're looking for.
      # If there is a match, and the bracket nesting count
      # if zero, we're done.  If there is a match, but the
      # nesting count is non-zero, decrement the count
      # and keep searching.
      if !searchignore(ch, forward)
	if ch == chdec
	  if count == 0
	    w.dot = dot
	    return Result::True
	  end
	  count -= 1
	elsif ch == chinc
	  count += 1
	end
      end
    end
    Echo.puts("Not found")
    w.dot = olddot
    return Result::False
  end

  # Creates key bindings for all Misc commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctrl('s'), cmdptr(forwsearch), "forw-search")
    k.add(Kbd.ctrl('r'), cmdptr(backsearch), "back-search")
    k.add(Kbd.meta_ctrl('s'), cmdptr(forwregsearch), "forw-regexp-search")
    k.add(Kbd.meta_ctrl('r'), cmdptr(backregsearch), "back-regexp-search")
    k.add(Kbd.meta_ctrl('f'), cmdptr(foldcase), "fold-case")
    k.add(Kbd.meta('p'), cmdptr(searchparen), "search-paren")
    k.add(Kbd.meta('r'), cmdptr(replstring), "replace-string")
    k.add(Kbd.meta('q'), cmdptr(queryrepl), "query-replace")
    k.add(Kbd.meta('/'), cmdptr(regrepl), "reg-replace")
    k.add(Kbd.meta('?'), cmdptr(regqueryrepl), "reg-query-replace")
    k.add(Kbd::F9, cmdptr(searchagain), "search-again")
  end
end
