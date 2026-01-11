# `Echo` contains routines for reading and writing characters in
# the so-called echo line area, the bottom line of the screen.
module Echo

  @@noecho = false
  @@empty = true

  extend self

  # Sets the `@@noecho` boolean to *x*.
  def self.noecho=(x : Bool)
    @@noecho = x
  end

  # Returns true if there is nothing on the echo line
  def self.empty?
    @@empty
  end

  # Below are special versions of the routines in Terminal that don't don't
  # do anything if the `@@noecho` variable is set.  This prevents echo
  # line activity from showing on the screen while we are
  # processing a profile.  "Noecho" is set to TRUE when a profile is
  # executed, and turned off temporarily by eprintf() to print error
  # messages (i.e. messages that don't start with '[').

  # Moves the cursor if `@@noecho` is false.
  def self.move(row : Int32, col : Int32)
    E.tty.move(row, col) unless @@noecho
  end

  # Writes the string *s* to the echo line, and erases the rest of the line.
  def self.puts(s : String)
    tty = E.tty
    tty.putline(tty.nrow - 1, 0, s)
    @@empty = false
  end

  # Erases the echo line.
  def self.erase
    tty = E.tty
    tty.move(tty.nrow - 1, 0)
    tty.eeol
    @@empty = true
  end

  # Writes *prompt* to the echo line, and reads back the response.
  # If *default* is not nil, use that as the initial value of the response,
  # which the user can edit as necessary.
  #
  # When the user hits Tab, calls the passed-in *block* with the response
  # so far, which returns the longest possible suffix that can be
  # added the response.  Returns a tuple containing a Result code and
  # the response string.  The Result code has these meanings:
  # * False - user entered an empty response
  # * True  - user entered a non-empty response
  # * Abort - user aborted the response with Ctrl-G
  def self.reply(prompt : String, default : String | Nil, &block) : Tuple(Result, String)
    tty = E.tty
    row = tty.nrow - 1
    leftcol = prompt.size
    fillcols = tty.ncol - leftcol
    tty.putline(row, 0, prompt)
    tty.move(row, leftcol)
    tty.flush
    @@empty = false

    ret = default || ""
    pos = ret.size
    done = false
    aborted = false
    lastc = ""

    # Set some commonly-used constants.
    ctrl_h = Kbd.ctrl('h')

    # Loop getting keys.
    until done
      # Redraw the ret buffer.
      if ret.size >= fillcols
	# Answer is too big to fit on screen.  Just show the right portion that
	# does fit.
	tty.putline(row, leftcol, ret[ret.size-fillcols .. ret.size-1])
        tty.move(row, tty.ncol - 1)
      else
        tty.putline(row, leftcol, ret)
        tty.move(row, leftcol + pos)
      end
      tty.flush

      c = E.kbd.getkey
      case c
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
        if !(c == ctrl_h && pos == 0)
	  if c == ctrl_h
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
	suffix = yield(ret)
	ret = ret + suffix
      else
	ret = ret.insert(pos, c.chr.to_s)	# convert codepoint to Char to String
	pos += 1
      end
      lastc = c
    end

    if aborted
      return {Result::Abort, ret}
    else
      if ret.size == 0
	return {Result::False, ret}
      else
	return {Result::True, ret}
      end
    end
  end

  # Prompts for a string, and echoes the response.
  def echo(f : Bool, n : Int32, k : Int32) : Result
    result, ret = Echo.reply("Echo: ", nil) {|s| ""}
    if result == Result::True
      Echo.puts(ret)
    end
    return result
  end

  # Creates key bindings for all Misc commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd.ctlx_ctrl('m'), cmdptr(echo), "echo")
  end

end
