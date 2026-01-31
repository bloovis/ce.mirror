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

  # Populates the system buffer with the completions information.
  # Try to display it with more than one entry per line.  Returns
  # true if successful, false otherwise.
  private def show_completions(a : Array(String)) : Bool
    # Grab the system buffer
    b = Buffer.sysbuf
    b.clear
    b.filename = ""

    # Find the largest name size.
    namesize = 0
    a.each { |name| namesize = [name.size, namesize].max }

    # Find out how many names will fit in a screen line.
    cols = E.tty.ncol // (namesize + 1)

    # Construct lines of text using cols as the number of columns.
    s = ""
    col = 0
    a.each_with_index do |name, i|
      if col == cols - 1 || i == a.size - 1
        s = s + " " + name
	b.addline(s)
	s = ""
	col = 0
      elsif col == 0
        s = name.pad_right(namesize)
	col = (col + 1) % cols
      else
	s = s + " " + name.pad_right(namesize)
	col = (col + 1) % cols
      end
    end

    # Pop up the buffer.
    status = Buffer.popsysbuf
    E.disp.update
    return status
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
    prompt = prompt.readable
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
      s = ret.readable
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
	  # Get an array of possible completions.
	  a = yield(ret)
	  if a.size == 1
	    ret = a[0]
	    break	# only one choice, so pretend that Enter was pressed
	  else
	    prefix = common_prefix(a)
	    if prefix.size > 0
	      lastk = Kbd::RANDOM if prefix.size > ret.size
	      ret = prefix
	      pos = ret.size
	    end
	  end
	  if lastk == Kbd.ctrl('i')
	    # Pop up the system buffer showing the possible completions.
	    show_completions(a)
	    lastk = Kbd::RANDOM
	  end
	else
	  # No completion block provided, so treat the Tab
	  # as an ordinary character to insert into the line.
	  ret = ret.insert(pos, "\t")
	  pos += 1
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
	s = ret.readable
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
      Buffer.each do |b|
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

  # Returns true if the file *filename* is a directory,
  # false otherwise.
  private def isdir(filename : String) : Bool
    info = File.info?(filename)
    #STDERR.puts("Checking info for #{filename}")
    return !info.nil? && info.directory?
  end

  # Prompts for a filename, and returns a tuple containing
  # the Result and the filename entered by the user
  def getfname(prompt : String) : Tuple(Result, String)
    # Use the directory portion of the current buffer's filename
    # as the default answer.
    default = nil
    b = E.curb
    if b.filename != ""
      dirname = File.dirname(b.filename)
      if dirname != "."
	default = dirname + "/"
      end
    end
    result, fname = do_reply(prompt, default, true) do |s|
      #STDERR.puts("completion block called with #{s}")
      # Break the string into the directory and base names.
      # But if the name ends with a slash, treat it as
      # the directory name.
      if s[-1] == '/'
	dirname = s[0...-1]
	basename = ""
      else
	dirname = File.dirname(s)
	basename = File.basename(s)
      end
      #STDERR.puts("dirname #{dirname}, base #{basename}")

      # Get the list of filenames in the directory that start with the basename.
      a = [] of String
      begin
        f = Files.tilde_expand(dirname)
        dir = Dir.new(f)
	dir.each do |f|
	  if f.starts_with?(basename)
	    if dirname == "/"
	      fullname = "/" + f	# Avoid multiple /
	    else
	      fullname = dirname + "/" + f
	    end
	    #STDERR.puts("fullname is #{fullname}")
	    if isdir(fullname) && fullname[-1] != '/'
	      #STDERR.puts("Adding slash to #{fullname}")
	      fullname = fullname + "/"
	    end
	    a << fullname
	  end
	end
      rescue
        #STDERR.puts("Unable to open #{dirname}")
        # Unable to open the directory.  Return an empty set.
      end

      # If there's only one file, and it's a directory, present a list of files
      # in that directory.
      if a.size == 1
	name = Files.tilde_expand(a[0])
	if name[-1] == '/'
	  # Remove trailing slash
	  name = name[0...-1]
	end
	if isdir(name)
	  begin
	    dir = Dir.new(name)
	    a = [] of String	# Clear the list
	    dir.each do |f|
	      if f != "." && f != ".."
		fullname = name + "/" + f
		#STDERR.puts("single dir #{name}: fullname #{fullname}")
		if isdir(fullname) && fullname[-1] != '/'
		  fullname = fullname + "/"
		  #STDERR.puts("single dir #{name}: adding slash to fullname #{fullname}")
		end
		a << fullname
	      end
	    end
	  rescue
	    # Can't open the directory.  Make a two-element list
	    # with just that directory name repeated twice.
	    # We need two elements to prevent the completion code
	    # in treating the directory name as the sole choice.
	    dirname = name # + "/"
	    a = [dirname, dirname]
	    #STDERR.puts("Adding two-element #{dirname}")
	  end
	end
      end
      a
    end

    # Return immediately on Ctrl-G abort.
    return {result, fname} if result == Result::Abort

    # Check for empty name.
    return {fname.size == 0 ? Result::False : Result::True, fname}
  end

  # Ask "yes" or "no" question.
  # Return ABORT if the user answers the question
  # with the abort ("^G") character. Return FALSE
  # for "no" and TRUE for "yes". No formatting
  # services are available.
  def yesno(prompt : String) : Result
    loop do
      r, s = Echo.reply("#{prompt} [y/n]? ", nil)
      return Result::Abort if r == Result::Abort
      if s.size > 0
	c = s[0].downcase
	return Result::True if c == 'y'
	return Result::False if c == 'n'
      end
    end
  end

  # Commands.

  # Prompts for a string, and echoes the response.
  def echo(f : Bool, n : Int32, k : Int32) : Result
    result, ret = Echo.reply("Echo: ", nil)
    if result == Result::True
      Echo.puts(ret.readable)
    end
    return result
  end

  # Creates key bindings for all Misc commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctlx_ctrl('m'), cmdptr(echo), "echo")
  end

end
