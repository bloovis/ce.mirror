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
      Echo.puts(nomsg)
      return FALSE
    end
    if s =~ /^\d+$/
      n = s.to_i
      if n < 1 || n > suggestions.size
	Echo.puts(nomsg)
	return FALSE
      end
      s = suggestions[n-1]
      Line.replace(word.size, s)
      Echo.puts("Replaced #{word} with #{s}")
      return TRUE
    else
      Line.replace(word.size, s)
      Echo.puts("Replaced #{word} with #{s}")
      return TRUE
    end
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
