# The `Spell` module implements spell-checking commands
# using ispell's interactive mode.

module Spell

  @@process : Process | Nil = nil
  @@debug = true

  extend self

  def dprint(s : String)
    STDERR.puts(s) if @@debug
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
      dprint("Created process for ispell")
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
	dprint("ispell identified itself as '#{s}'")
      end
      return true
    else
      return false
    end
  end

  # Finds the word under the cursor and returns it, leaving
  # the cursor past the end of the word.
  def getcursorword : String | Nil
    s = ""
    # If we're not already in a word, return nil
    return nil if !Word.inword

    # Scan back to the beginning of the word.
    dot = E.curw.dot
    while dot.o > 0 && Word.inword
      dot.o -= 1
    end
    if !Word.inword
      dot.o += 1
    end

    # Scan forward past the end of word, accumulating its
    # characters as we go.
    while Word.inword
      s = s + Line.getc.to_s
      dot.o += 1
    end
    return s
  end

  # Asks the user for a replacement for *word*, using the suggestions
  # contained in the line *rest*.
  private def get_replacement(word : String, rest : String) : Result
    #Echo.puts("Using /,\s*/ to split '#{rest}'")
    # Pop up the system buffer showing the suggested replacements
    suggestions = rest.split(/,\s*/)
    b = Buffer.sysbuf
    b.clear
    suggestions.each_with_index do |s,i|
      b.addline("#{i}: #{s}")
    end
    return FALSE if !Buffer.popsysbuf
    E.disp.update

    # Prompt the user to enter a response indicating an action to take.
    # The actions are:
    # * Ctrl-G or Q or empty string: do nothing
    # * R: prompt the user for a replacement string
    # * N (number): use ispell's N'th suggested replacement
    prompt = "R=replace,N=use N'th suggestion: "
    result, s = Echo.reply(prompt, nil)
    return result if result == ABORT
    if s.upcase == "R"
      result, s = Echo.reply("Replacement string: ", nil)
      return result if result != TRUE
      Line.replace(word.size, s)
      Echo.puts("Replaced #{word} with #{s}")
      return TRUE
    end
    if s =~ /^\d+$/
      n = s.to_i
      if n < 0 || n >= suggestions.size
	Echo.puts("No replacement done")
	return FALSE
      end
      s = suggestions[n]
      Line.replace(word.size, s)
      Echo.puts("Replaced #{word} with #{s}")
      return TRUE
    end
    Echo.puts("No replacement done")
    return FALSE
  end

  # Runs ispell on the word under the curso.  If ispell
  # thinks the word is misspelled, prompts the user for
  # replacement, and pops up the system buffer showing
  # the suggested replacements.
  def spellword(f : Bool, n : Int32, key : Int32) : Result
    if !open_ispell
      Echo.puts("Unable to open a pipe to ispell")
      s = getcursorword
      if s
	return TRUE
      else
	Echo.puts("Didn't find a word")
	return FALSE
      end
    end

    # Get the word under the cursor, if any.
    word = getcursorword
    if word
      Echo.puts("Got word #{word}")
    else
      Echo.puts("No word under cursor")
      return FALSE
    end

    # Write the word to ispell.
    f = nil
    if p = @@process
      f = p.input?
    end
    unless f
      dprint("Can't open spell's input file handle")
      return FALSE
    end
    f.puts word

    # Read the response from ispell.
    f = nil
    if p
      f = p.output?
    end
    unless f    
      Echo.puts("Can't open ispell's output file handle")
      return FALSE
    end

    # Read the response.  If it's non-blank, read the next
    # line, which WILL be blank.
    buf = f.gets
    if buf.nil?
      Echo.puts("Can't read from ispell")
      return FALSE
    end
    if buf.size > 0
      f.gets
    end
    #Echo.puts("ispell response to #{word} is '#{buf}'")

    # A blank response means ispell doesn't know what to
    # do with the word.
    if buf.size == 0
      Echo.puts("ispell doesn't recognize #{word} as a word")
      return FALSE
    end

    # Examine the response.
    case buf[0]
    when '*'
      Echo.puts("#{word} is spelled correctly")
      return TRUE
    when '+'
      Echo.puts("#{word} is spelled correctly via root #{buf[2..]}")
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
	    return get_replacement(word, rest)
	  else
	    Echo.puts("Couldn't parse response '#{buf}'")
	    return FALSE
	  end
	else
	  Echo.puts("Couldn't parse response '#{buf}'")
	  return FALSE
	end
      else
	Echo.puts("Invalid response '#{buf}'")
        return FALSE
      end
    else
      Echo.puts("Unrecognized response '#{buf}'")
      return FALSE
    end
    return TRUE
  end

  # Creates key bindings for all RubyRPC commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.meta('$'), cmdptr(spellword), "spell-word")
  end

end
