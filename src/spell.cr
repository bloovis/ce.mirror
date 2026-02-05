# The `Spell` module implements spell-checking commands
# using ispell's interactive mode.

module Spell

  @@process : Process | Nil = nil
  @@regex = /[a-zA-Z']/	 # regex for recognizing "word" characters

  extend self

  # Returns true if the character at the dot
  # is considered to be part of a word.  This is different
  # from Word.inword, because it considers only
  # alphas and apostrpophes to be word characters.
  def inword
    return Line.getc.to_s =~ @@regex
  end

  # Opens a two-way pipe to the ispell program.  Returns true
  # if successful, false otherwise.
  def open_ispell : Bool
    if !@@process.nil?
      return true
    end

    begin
      @@process = Process.new("ispell",
			     ["-a"],
                             input: Process::Redirect::Pipe,
                             output: Process::Redirect::Pipe,
                             error: Process::Redirect::Pipe,
			     shell: false)
      E.log("Created process for ispell")
    rescue IO::Error
      Echo.puts("Unable to create process for ispell")
      @@process = nil
      return false
    end

    # Read the identification message from ispell.
    if p = @@process
      f = p.output?
      if f
	s = f.gets
	E.log("ispell identified itself as '#{s}'")
      end
      return true
    else
      return false
    end
  end

  # Returns ispell's output file, or nil if the ispell
  # process is dead.
  private def ispell_output : IO | Nil
    f = nil
    if p = @@process
      f = p.output?
    end
    if f.nil?
      Echo.puts("Can't open ispell's output file handle")
     end
    return f
  end

  # Returns ispell's input file, or nil if the ispell
  # process is dead.
  private def ispell_input : IO | Nil
    f = nil
    if p = @@process
      f = p.input?
    end
    if f.nil?
      Echo.puts("Can't open ispell's input file handle")
    end
    return f
  end

  # Finds the word under the cursor and returns it, leaving
  # the cursor past the end of the word.
  def getcursorword : String | Nil
    s = ""
    # If we're not already in a word, return nil
    return nil if !inword

    # Scan back to the beginning of the word.
    dot = E.curw.dot
    while dot.o > 0 && inword
      dot.o -= 1
    end
    if !inword
      dot.o += 1
    end

    # Scan forward past the end of word, accumulating its
    # characters as we go.
    while inword
      s = s + Line.getc.to_s
      dot.o += 1
    end
    return s
  end

  # Asks the user for a replacement for *word*, using the suggestions
  # contained in the line *rest*.
  private def get_replacement(word : String, rest : String, info : Bool) : Result
    #Echo.puts("Using /,\s*/ to split '#{rest}'")
    # Split the ispell response into a list of suggestions.
    suggestions = rest.split(/,\s*/)

    # Determine the size of the largest suggestion, adding 5
    # for a prefix "NNN: ", where NNN is a suggestion number.
    # There should not be more than 99 suggestions, but we'll
    # allow for more just in case.
    ssize = suggestions.map {|s| s.size + 5}.max

    # Add a header line.
    b = Buffer.sysbuf
    b.clear
    b.addline("Suggested replacements for #{word}:")

    # Find out how many suggestions will fit in a screen line.
    cols = E.tty.ncol // (ssize + 1)	# +1 for space separator

    # Construct lines of text using cols as the number of columns.
    s = ""
    col = 0
    suggestions.each_with_index do |sugg, i|
      sugg = "#{i+1}: " + sugg
      if col == cols - 1 || i == suggestions.size - 1
        s = s + (col == 0 ? "" : " ") + sugg
	b.addline(s)
	s = ""
	col = 0
      elsif col == 0
        s = sugg.pad_right(ssize)
	col = (col + 1) % cols
      else
	s = s + " " + sugg.pad_right(ssize)
	col = (col + 1) % cols
      end
    end

    # Pop up the system buffer showing the suggested replacements
    return FALSE if !Buffer.popsysbuf
    E.disp.update

    # Prompt the user to enter a response containing a replacement
    # string, or the number of an ispell-suggested replacement.
    nomsg = "No replacement done"
    prompt = "Replacement string or suggestion number (#{1} to #{suggestions.size}): "
    result, s = Echo.reply(prompt, nil)
    if result != TRUE
      # User didn't enter a replacement, so tell ispell to accept this
      # word in the future.
      if result == FALSE
	if fin = ispell_input
	  fin.puts("@#{word}")
	end
      end
      Echo.puts(nomsg) if info
      return result
    end
    if s =~ /^\d+$/
      n = s.to_i
      if n < 1 || n > suggestions.size
	Echo.puts(nomsg) if info
	return FALSE
      end
      s = suggestions[n-1]
      Line.replace(word.size, s)
      Echo.puts("Replaced #{word} with #{s}") if info
      return TRUE
    else
      Line.replace(word.size, s)
      Echo.puts("Replaced #{word} with #{s}") if info
      return TRUE
    end
  end

  # Runs ispell on the word under the curso.  If ispell
  # thinks the word is misspelled, prompts the user for
  # replacement, and pops up the system buffer showing
  # the suggested replacements.
  def checkword(info : Bool) : Result
    if !open_ispell
      Echo.puts("Unable to open a pipe to ispell")
      return ABORT
    end

    # Get the word under the cursor, if any.
    word = getcursorword
    if word.nil?
      Echo.puts("No word under cursor") if info
      return FALSE
    end

    # Write the word to ispell.
    return ABORT unless fin = ispell_input
    fin.puts word

    # Read the response from ispell.
    return ABORT unless fout = ispell_output

    # Read the response.  If it's non-blank, read more lines
    # until we find a blank line.
    buf = fout.gets
    if buf.nil?
      Echo.puts("Can't read response from ispell")
      return ABORT
    end
    if buf.size > 0
      while true
        s = fout.gets
	if s.nil?
	  Echo.puts("Can't read blank line from ispell")
	  return ABORT
	end
	break if s == ""
      end
    end
    #Echo.puts("ispell response to #{word} is '#{buf}'")

    # A blank response means ispell doesn't know what to
    # do with the word.
    if buf.size == 0
      Echo.puts("ispell doesn't recognize #{word} as a word") if info
      return FALSE
    end

    # Examine the response.
    case buf[0]
    when '*'
      Echo.puts("#{word} is spelled correctly") if info
      return TRUE
    when '+'
      Echo.puts("#{word} is spelled correctly via root #{buf[2..]}") if info
      return TRUE
    when '#', '&', '?'
      # Ignore the first part of the response, which gives
      # the original word, an offset, and possibly the
      # number of guesses.
      if buf[0] == '#'
	regex = /\s*\w+\s+\d+\s*(.*)/
      else
	regex = /\s*\w+\s+\d+\s+\d+:\s*(.*)/
      end
      if buf.size > 1
	if m = regex.match(buf[1..])
	  rest = m[1]?
	  if rest
	    return get_replacement(word, rest, info)
	  else
	    Echo.puts("Missing replacements in '#{buf}'")
	    return ABORT
	  end
	else
	  Echo.puts("Couldn't parse response '#{buf}'")
	  return ABORT
	end
      else
	Echo.puts("Invalid response '#{buf}'")
        return ABORT
      end
    else
      Echo.puts("Unrecognized response '#{buf}'")
      return ABORT
    end
    return TRUE
  end

  # Checks spelling in the word under the cursor.
  def spellword(f : Bool, n : Int32, key : Int32) : Result
    return checkword(true)
  end

  # Checks spelling in the current marked region.
  def spellregion(f : Bool, n : Int32, key : Int32) : Result
    w = E.curw
    region = Region.new
    return FALSE if region.start.l == -1	# invalid region
    w.dot = region.start
    status = TRUE
    while true
      # Abort if we're past the end of the region.
      break if w.dot.cmp(region.finish) >= 0

      # Scan forward to the next word.
      while !inword
	# Abort if we're at the end of the buffer
	break TRUE if Basic.forwchar(false, 1, Kbd::RANDOM) != TRUE
      end
      break if !inword

      # Abort if we're past the end of the region.
      break if w.dot.cmp(region.finish) >= 0

      # Check this word, and abort if checkword says to abort.
      status = checkword(false)
      break if status == ABORT
    end
    Echo.puts("Done")	# clear any existing prompt
    return status
  end

  # Creates key bindings for all RubyRPC commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.meta('$'), cmdptr(spellword), "spell-word")
    k.add(Kbd.ctlx('i'), cmdptr(spellregion), "spell-region")
  end

end
