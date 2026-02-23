# The `Spell` module implements spell-checking commands
# using aspell's interactive mode (`aspell -a`)
module Spell

  @@process : Process | Nil = nil
  @@regex = /[a-zA-Z']/	 # regex for recognizing "word" characters

  extend self

  # Returns true if the character at the dot
  # is considered to be part of a word.  This is different
  # from `Word.inword`, because it considers only
  # alphas and apostrophes to be word characters.
  def inword
    return Line.getc.to_s =~ @@regex
  end

  # Opens a two-way pipe to the aspell program.  Returns true
  # if successful, false otherwise.
  def open_aspell : Bool
    if !@@process.nil?
      return true
    end

    # -a means ispell pipe mode.
    # --lang sets the language to be used.
    args = ["-a"]
    lang = E.curb.spelling_language
    if lang != ""
      args << "--lang=#{lang}"
    end

    begin
      @@process = Process.new("aspell",
			     args,
                             input: Process::Redirect::Pipe,
                             output: Process::Redirect::Pipe,
                             error: Process::Redirect::Pipe,
			     shell: false)
      E.log("Created process for aspell")
    rescue IO::Error
      Echo.puts("Unable to create process for aspell")
      @@process = nil
      return false
    end

    # Read the identification message from aspell.
    if p = @@process
      f = p.output?
      if f
	s = f.gets
	E.log("aspell identified itself as '#{s}'")
      end
      return true
    else
      return false
    end
  end

  # Returns aspell's output file, or nil if the aspell
  # process is dead.
  private def aspell_output : IO | Nil
    f = nil
    if p = @@process
      f = p.output?
    end
    if f.nil?
      Echo.puts("Can't open aspell's output file handle")
     end
    return f
  end

  # Returns aspell's input file, or nil if the aspell
  # process is dead.
  private def aspell_input : IO | Nil
    f = nil
    if p = @@process
      f = p.input?
    end
    if f.nil?
      Echo.puts("Can't open aspell's input file handle")
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

  # Asks the user for a replacement for *word*, using the comma-separated
  # suggestions contained in the line *rest*.  The *info* parameter
  # is true if `get_replacement` should display information about what
  # it's doing on the echo line.
  private def get_replacement(word : String, rest : String, info : Bool) : Result
    #Echo.puts("Using /,\s*/ to split '#{rest}'")
    # Split the aspell response into a list of suggestions.
    suggestions = rest.split(/,\s*/)

    # Make a set of names with the number of each name as a prefix.
    i = 0
    names = suggestions.map {|s| i += 1; "#{i}: #{s}"}

    # Grab the sysbuf and add a header line.
    b = Buffer.sysbuf
    b.clear
    b.addline("Suggested replacements for #{word}:")

    # Add the suggestions to the sysbuf.
    Echo.add_names_to_sysbuf(b, names)

    # Pop up the system buffer showing the suggested replacements
    return FALSE if !Buffer.popsysbuf
    E.disp.update

    # Prompt the user to enter a response containing a replacement
    # string, or the number of an aspell-suggested replacement.
    nomsg = "No replacement done"
    prompt = "Replacement string or suggestion number (#{1} to #{suggestions.size}): "
    result, s = Echo.reply(prompt, nil)
    if result != TRUE
      # User didn't enter a replacement, so tell aspell to accept this
      # word in the future.
      if result == FALSE
	if fin = aspell_input
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

  # Runs aspell on the word under the cursor.  If aspell
  # thinks the word is misspelled, prompts the user for
  # replacement, and pops up the system buffer showing
  # the suggested replacements.  The *info* parameter
  # is true if `checkword` should display information
  # about what it's doing on the echo line.
  def checkword(info : Bool) : Result
    if !open_aspell
      Echo.puts("Unable to open a pipe to aspell")
      return ABORT
    end

    # Get the word under the cursor, if any.
    word = getcursorword
    if word.nil?
      Echo.puts("No word under cursor") if info
      return FALSE
    end

    # Write the word to aspell.
    return ABORT unless fin = aspell_input
    fin.puts word

    # Read the response from aspell.
    return ABORT unless fout = aspell_output

    # Read the response.  If it's non-blank, read more lines
    # until we find a blank line.
    buf = fout.gets
    if buf.nil?
      Echo.puts("Can't read response from aspell")
      return ABORT
    end
    if buf.size > 0
      while true
        s = fout.gets
	if s.nil?
	  Echo.puts("Can't read blank line from aspell")
	  return ABORT
	end
	break if s == ""
      end
    end
    #Echo.puts("aspell response to #{word} is '#{buf}'")

    # A blank response means aspell doesn't know what to
    # do with the word.
    if buf.size == 0
      Echo.puts("aspell doesn't recognize #{word} as a word") if info
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

  # Commands.

  # This command checks spelling in the word under the cursor.
  def spellword(f : Bool, n : Int32, key : Int32) : Result
    return checkword(true)
  end

  # This command checks spelling in the current marked region.
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

  # Creates key bindings for all Spell commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.meta('$'), cmdptr(spellword), "spell-word")
    k.add(Kbd.ctlx('i'), cmdptr(spellregion), "spell-region")
  end

end
