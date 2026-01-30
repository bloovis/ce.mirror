require "system/user"

# The `Files` module contains some commands dealing with files.
module Files

  extend self

  # Checks whether the current buffer is read-only.  It if is,
  # display an error message and return FALSE; otherwise return TRUE.
  def checkreadonly
    w = E.curw
    b = w.buffer
    if b.flags.read_only?
      Echo.puts("Buffer is read-only")
      return false
    else
      return true
    end
  end

  # Expands a path contain a tilde user reference, replacing ~ alone
  # with the current user's home directory, and replacing ~name with
  # that user's home directory.
  def tilde_expand(s : String) : String
    if s =~ /(~([^\s\/]*))/ # twiddle directory expansion
      full = $1
      name = $2
      if name.empty?
	#STDERR.puts "User name is empty in #{s}"
	dir = Path.home.to_s
      else
	#STDERR.puts "Looking up user #{name}"
	if u = System::User.find_by?(name: name)
	  dir = u.home_directory
	  #STDERR.puts "Found user #{name}, home directory #{dir}"
	else
	  dir = "~#{name}"	# probably doesn't exist!
	end
      end
      #STDERR.puts "Replacing #{full} with #{dir} in #{s}"
      return s.sub(full, dir)
    else
      #STDERR.puts "No twiddle seen in #{s}"
      return s
    end
  end

  # Selects a file for editing.
  # Looks around to see if you can find the
  # file in another buffer; if you can find it
  # just switches to the buffer. If you cannot find
  # the file, creates a new buffer, reads in the
  # text, and switches to the new buffer.
  #
  # visit_file is a helper function for filevisit.
  # It takes the filename to read as a parameter.
  # It's also used by tags.
  def visit_file(fname : String) : Result
    curw = E.curw		# Current window
    fname = tilde_expand(fname)	# Get fully expanded filename

    # Look for a buffer already associated with this file.
    Buffer.each do |b|
      if b.filename == fname
	# Found a buffer with this file.  Make the current
	# window use that buffer.
	curw.buffer = b

	# If there's another window using this buffer,
	# copy its dot and mark.
	Window.each do |w|
	  if w != curw && w.buffer == b
	    curw.dot = w.dot.dup
	    curw.mark = w.mark.dup
	    break
	  end
	end

	# Frame the window so that the dot is near
	# the middle of the window.
	curw.line = [curw.dot.l - (curw.nrow // 2), 0].max
	Echo.puts("[Old buffer]")
	return Result::True
      end
    end

    # Didn't find a buffer associated with this file,
    # so must create a new buffer.
    b = Buffer.new("", fname)

    # Save this window's old buffer name.
    E.oldbufn = curw.buffer.name

    # Associate the new buffer with the current window.
    curw.buffer = b

    # Read the file.
    return b_to_r(b.readin(fname))
  end

  # Commands.

  # Toggles the read-only state of the current buffer.
  def togglereadonly(f : Bool, n : Int32, k : Int32) : Result
    b = E.curb
    b.flags = b.flags ^ Bflags::ReadOnly
    if b.flags.read_only?
      Echo.puts("Buffer is now read-only")
    else
      Echo.puts("Buffer is now read-write")
    end
    return Result::True
  end

  # Saves the contents of the current buffer back into
  # its associated file. Do nothing if there have been no changes
  # (is this a bug, or a feature). Error if there is no remembered
  # file name.
  def filesave(f : Bool, n : Int32, k : Int32) : Result
    b = E.curb
    return Result::True unless b.flags.changed?
    if b.filename == ""
      Echo.puts("No file name")
      return Result::False
    end
    if b.writeout
      b.lchange(false)	# mark buffer as unchanged
      return Result::True
    else
      return Result::False
    end
  end

  # Prompts for a file, then opens that file.  If a buffer with that
  # file already exists, uses it; others creates a new buffer.
  def filevisit(f : Bool, n : Int32, k : Int32) : Result
    result, fname = Echo.getfname("Visit file: ")
    return result if result != Result::True
    return visit_file(fname)
  end


  # Asks for a file name, and write the
  # contents of the current buffer to that file.
  # Update the remembered file name and clear the
  # buffer changed flag.  Unlike MicroEMACS, checks
  # if the file exists and asks the user if this is OK.
  def filewrite(f : Bool, n : Int32, k : Int32) : Result
    result, fname = Echo.getfname("Write file: ")
    return result if result != Result::True
    fname = tilde_expand(fname)

    # Check for existing file.
    b = E.curb
    if File.exists?(fname)
      if Echo.yesno("Overwrite existing file") != Result::True
	return Result::False
      end
    end

    # Change the buffer filename and write the file.
    b.filename = fname
    if b.writeout
      b.lchange(false)	# mark buffer as unchanged
      return Result::True
    else
      return Result::False
    end
  end

  # Creates key bindings for all Files commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctlx_ctrl('q'), cmdptr(togglereadonly), "toggle-readonly")
    k.add(Kbd.ctlx_ctrl('s'), cmdptr(filesave), "file-save")
    k.add(Kbd.ctlx_ctrl('v'), cmdptr(filevisit), "file-visit")
    k.add(Kbd.ctlx_ctrl('w'), cmdptr(filewrite), "file-write")
  end

end
