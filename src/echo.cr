# `Echo` contains routines for reading and writing characters in
# the so-called echo line area, the bottom line of the screen.
module Echo

  @@noecho = false
  @@empty = true

  extend self

  # Sets the `@@noecho` boolean to *x*.
  def noecho=(x : Bool)
    @@noecho = x
  end

  # Returns true if there is nothing on the echo line
  def empty?
    @@empty
  end

  # Below are special versions of the routines in Terminal that don't don't
  # do anything if the `@@noecho` variable is set.  This prevents echo
  # line activity from showing on the screen while we are
  # processing a profile.  "Noecho" is set to TRUE when a profile is
  # executed, and turned off temporarily by eprintf() to print error
  # messages (i.e. messages that don't start with '[').

  # Moves the cursor if `@@noecho` is false.
  def move(row : Int32, col : Int32)
    E.tty.move(row, col) unless @@noecho
  end

  # Writes the string *s* to the echo line, and erases the rest of the line.
  def puts(s : String)
    tty = E.tty
    tty.putline(tty.nrow - 1, 0, s)
    @@empty = false
  end

  # Erases the echo line.
  def erase
    tty = E.tty
    tty.move(tty.nrow - 1, 0)
    tty.eeol
    @@empty = true
  end


  # Returns the largest common prefix of the
  # array of strings *a*.
  private def common_prefix(a : Array(String)) : String
    return "" if a.size == 0
    prefix = ""
    f = a.first
    (0 ... f.size).each do |i|
      c = f[i]
      break unless a.all? { |s| s[i]? == c }
      prefix += f[i].to_s
    end
    prefix
  end

  # Returns a readable version of the string *s*, where
  # control characters are replaced by ^C, where C is
  # the corresponding letter.
  def readable(s : String) : String
    s = s.gsub do |c|
      if c.ord >= 0x01 && c.ord <= 0x1a
	"^" + (c + '@'.ord).to_s
      else
	c
      end
    end
    return s
  end

  # Returns the screen width of the first *n* characters of string *s*,
  # where control characters are treated as having a width of two.
  def screenwidth(s : String, n : Int32) : Int32
    width = 0
    s.each_char do |c|
      break if n == 0
      n -= 1
      if c.ord >= 0x01 && c.ord <= 0x1a
	width += 2
      else
	width += 1
      end
    end
    return width
  end

  # Writes *prompt* to the echo line, and reads back the response.
  # If *default* is not nil, use that as the initial value of the response,
  # which the user can edit as necessary.
  #
  # When the user hits Tab, calls the passed-in *block* with the response
  # so far, which returns an array of strings that start with that string.
  # Returns a tuple containing a Result code and the response string.
  # The Result code has these meanings:
  # * False - user entered an empty response
  # * True  - user entered a non-empty response
  # * Abort - user aborted the response with Ctrl-G
  private def do_reply(prompt : String, default : String | Nil,
		    block_given : Bool, &block) : Tuple(Result, String)
    tty = E.tty
    row = tty.nrow - 1
    leftcol = prompt.size
    fillcols = tty.ncol - leftcol
    tty.putline(row, 0, prompt)
    tty.move(row, leftcol)
    tty.flush
    @@empty = false

    ret = ""
    pos = ret.size
    done = false
    aborted = false
    lastk = Kbd::RANDOM

    # Set some commonly-used constants.
    ctrl_h = Kbd.ctrl('h')

    # Loop getting keys.
    until done
      # Redraw the ret buffer.
      s = readable(ret)
      if s.size >= fillcols
	# Answer is too big to fit on screen.  Just show the right portion that
	# does fit.
	tty.putline(row, leftcol, s[s.size-fillcols .. s.size-1])
        tty.move(row, tty.ncol - 1)
      else
        tty.putline(row, leftcol, s)
        tty.move(row, screenwidth(ret, pos) + leftcol)
      end
      tty.flush

      k = E.kbd.getkey
      case k
      when Kbd.ctrl('a')
        pos = 0
      when Kbd.ctrl('e')
        pos = ret.size
      when Kbd::LEFT, Kbd.ctrl('b')
        if pos > 0
	  pos -= 1
	end
      when Kbd::RIGHT, Kbd.ctrl('f')
        if pos < ret.size
	  pos += 1
	end
      when ctrl_h, Kbd::DEL, Kbd.ctrl('d')
        if !(k == ctrl_h && pos == 0)
	  if k == ctrl_h
	    pos -= 1
	  end
	  left = (pos == 0) ? "" : ret[0..pos-1]
	  right = (pos >= ret.size - 1) ? "" : ret[pos+1..]
	  ret = left + right
	end
      when Kbd.ctrl('k')
        if pos == 0
	  ret = ""
	else
	  ret = ret[0..pos-1]
	end
      when Kbd.ctrl('u')
        ret = ""
	pos = 0
      when Kbd.ctrl('m')
        done = true
      when Kbd.ctrl('g')
	done = true
	tty.puts("^G")
	tty.eeol
	aborted = true
      when Kbd.ctrl('i')
        pos = ret.size
	if block_given
	  a = yield(ret)
	  if a.size == 1
	    ret = a[0]
	    break	# only one choice, so pretend that Enter was pressed
	  else
	    ret = common_prefix(a)
	    pos = ret.size
	  end
	end
      when Kbd.ctrl('s')
        if default
	  ret = ret.insert(pos, default)
	  pos += default.size
	end
      else
	# Get the ASCII-fied character and insert it into the buffer. 
	s = Kbd.ascii(k)
	ret = ret.insert(pos, s)	# convert codepoint to Char to String
	pos += 1
      end
      lastk = k
    end

    if aborted
      return {Result::Abort, ret}
    else
      if ret.size == 0
	# If the user didn't enter anything, but there is a default,
	# return the default.
	ret = default || ret
	return {Result::False, ret}
      else
	# Display the entire string before returning it.
	s = readable(ret)
        tty.putline(row, leftcol, s)
	tty.flush
	return {Result::True, ret}
      end
    end
  end

  # Calls `do_reply` without a completion block.
  def reply(prompt : String, default : String | Nil) : Tuple(Result, String)
    do_reply(prompt, default, false) {[""]}
  end

  # Prompts for a buffer name, and returns a tuple containing
  # the Result and the name entered by the user
  def getbufn : Tuple(Result, String)
    result, bufn = do_reply("Use buffer [#{E.oldbufn}]: ", nil, true) do |s|
      a = [] of String
      Buffer.buffers.each do |b|
        if b.name.starts_with?(s)
	  a << b.name
	end
      end
      a
    end

    # Return immediately on Ctrl-G abort.
    return {result, bufn} if result == Result::Abort

    # Use old buffer name if no name specified.
    if result == Result::False || bufn.size == 0
      bufn = E.oldbufn
    end

    # Check for empty name.
    return {bufn.size == 0 ? Result::False : Result::True, bufn}
  end

  # Ask "yes" or "no" question.
  # Return ABORT if the user answers the question
  # with the abort ("^G") character. Return FALSE
  # for "no" and TRUE for "yes". No formatting
  # services are available.
  def yesno(prompt : String) : Bool
    return false
    loop do
      r, s = Echo.reply("#{prompt} [y/n]? ", nil)
      return false if result == Result::Abort
      if s.size > 0
	c = s[0].downcase
	return true if c == 'y'
	return false if c == 'n'
      end
    end
  end

  # Commands.

  # Prompts for a string, and echoes the response.
  def echo(f : Bool, n : Int32, k : Int32) : Result
    result, ret = Echo.reply("Echo: ", nil)
    if result == Result::True
      Echo.puts(readable(ret))
    end
    return result
  end

  # Creates key bindings for all Misc commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctlx_ctrl('m'), cmdptr(echo), "echo")
  end

end
