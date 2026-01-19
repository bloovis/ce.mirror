# `Basic` contains basic command functions for moving the
# cursor around on the screen, setting mark, and swapping dot with
# mark. Only moves between lines, which might make the
# current buffer framing bad, are hard.
module Basic
  @@curgoal = 0

  extend self

  # Checks if the dot must move after the current window has been
  # scrolled by forw-page or back-page.
  private def checkdot(w : Window)
    # Do nothing if dot is visible.
    dot = w.dot
    return if dot.l >= w.line && dot.l < w.line + w.nrow

    # Move the dot to halfway point in the window, or to the end
    # the buffer if the halfway point is past the end.
    dot.l = w.line + (w.nrow // 2)
    bsize = w.buffer.size
    dot.l = bsize - 1 if dot.l >= bsize
    dot.o = 0
  end

  # Goes to the beginning of the line.
  def gotobol(f : Bool, n : Int32, k : Int32) : Result
    E.curw.dot.o = 0
    return Result::True
  end

  # Goes to the end of the line.
  def gotoeol(f : Bool, n : Int32, k : Int32) : Result
    w = E.curw
    b = w.buffer
    dot = w.dot
    lp = b[dot.l]
    if lp
      dot.o = lp.text.size
    else
      raise "Nil line in gotobol!"
    end
    return Result::True
  end

  # Goes to the beginning of the
  # buffer. Setting WFHARD is conservative,
  # but almost always the case.
  def gotobob(f : Bool, n : Int32, k : Int32) : Result
    w = E.curw
    w.dot.l = 0
    w.dot.o = 0
    w.flags |= Wflags::Hard
    return Result::True
  end

  # Goes to the end of the buffer.
  # Setting WFHARD is conservative, but
  # almost always the case.
  def gotoeob(f : Bool, n : Int32, k : Int32) : Result
    w = E.curw
    b = w.buffer
    last = b.size - 1
    if last < 0
      last = 0
    end
    lp = b[last]
    if lp
      w.dot.l = last
      w.dot.o = lp.text.size
    else
      raise "Nil line in gotoeob!"
    end
    w.flags |= Wflags::Hard
    return Result::True
  end

  # Scrolls forward by a specified number
  # of lines, or by a full page if no argument.
  # The "5" is the window overlap (from ITS EMACS).
  # Because the top line in the window is zapped,
  # we have to do a hard update and get it back.
  def forwpage(f : Bool, n : Int32, k : Int32) : Result
    # Compute how much to scroll to get to next page
    # (80% of the screen size is what ITS EMACS seems to use).
    w = E.curw
    nrow = w.nrow
    page = w.nrow - (w.nrow // 5)
    page = 1 if page <= 0
    if !f
      n = page		# Default scroll
    elsif n < 0
      return backpage(f, -n, Kbd::RANDOM)
    else
      n *= page		# Convert from pages to lines
    end
    
    # Move the current line number down, but not past the end of the buffer.
    w.line += n
    bsize = w.buffer.size
    w.line = bsize - 1 if w.line >= bsize

    # This is a hard update (i.e., entire window must be redrawn).
    w.flags |= Wflags::Hard

    checkdot(w)
    return Result::True
  end

  # This command is like "forwpage",
  # but it goes backwards. The "5", like above,
  # is the overlap between the two windows. The
  # hard update is done because the top line in
  # the window is zapped.
  def backpage(f : Bool, n : Int32, k : Int32) : Result
    # Compute how much to scroll to get to next page
    # (80% of the screen size is what ITS EMACS seems to use).
    w = E.curw
    nrow = w.nrow
    page = w.nrow - (w.nrow // 5)
    page = 1 if page <= 0
    if !f
      n = page		# Default scroll
    elsif n < 0
      return forwpage(f, -n, Kbd::RANDOM)
    else
      n *= page		# Convert from pages to lines
    end
      
    # Move the current line number up, but not past the start of the buffer.
    w.line -= n
    w.line = 0 if w.line < 0

    # This is a hard update (i.e., entire window must be redrawn).
    w.flags |= Wflags::Hard

    checkdot(w)
    return Result::True
  end

  # Move cursor backwards. Do the
  # right thing if the count is less than
  # 0. Error if you try to move back
  # from the beginning of the buffer.
  def backchar(f : Bool, n : Int32, k : Int32) : Result
    if n < 0
      return forwchar(f, -n, Kbd::RANDOM)
    end
    w = E.curw
    b = w.buffer
    bsize = b.size
    dot = w.dot
    lp = b[dot.l]
    while n > 0
      if lp.nil?
	raise "Nil line in forwchar!"
      end
      if n > dot.o		# need to back up to previous line?
	if dot.l == 0		# already on first line?
	  dot.o = 0
	  n = 0
	else
	  lp = lp.previous	# move to previous line
	  n -= dot.o + 1	# +1 is for invisible newline
	  dot.l -= 1
	  if lp
	    dot.o = lp.text.size
	  end
	end
      else			# stay on this line
	dot.o -= n
	n = 0
      end
    end
    return Result::True
  end

  # Move cursor forwards. Do the
  # right thing if the count is less than
  # 0. Error if you try to move forward
  # from the end of the buffer.
  def forwchar(f : Bool, n : Int32, k : Int32) : Result
    if n < 0
      return backchar(f, -n, Kbd::RANDOM)
    end
    w = E.curw
    b = w.buffer
    bsize = b.size
    dot = w.dot
    lp = b[dot.l]
    while n > 0
      if lp.nil?
	raise "Nil line in forwchar!"
      end
      lsize = lp.text.size	# total size of this line
      rem = lsize - dot.o	# remaining chars in this line
      if n > rem		# need to advance to next line?
	if dot.l + 1 == bsize	# already on last line?
	  dot.o = lsize
	  n = 0
	else
	  lp = lp.next		# move to next line
	  n -= rem + 1		# +1 is for invisible newline
	  dot.l += 1
	  dot.o = 0
	end
      else			# stay on this line
	dot.o += n
	n = 0
      end
    end
      
    return Result::True
  end

  # Set the current goal column,
  # which is saved in the external variable "curgoal",
  # to the current cursor column. The column is never off
  # the edge of the screen; it's more like display then
  # show position.
  private def setgoal(lp : Pointer(Line), offset : Int32)
    @@curgoal = Display.screen_size(lp.text, offset)
  end

  # This routine looks at the line *lp* and the current
  # vertical motion goal column (set by the "setgoal"
  # routine above) and returns the best offset to use
  # when a vertical motion is made into the line.
  private def getgoal(lp : Pointer(Line)) : Int32
    col = 0
    dbo = 0
    tabsize = Tabs.tabsize
    lp.text.each_char_with_index do |c, i|
      newcol = col
      if c == '\t'
	newcol += tabsize - (newcol % tabsize) - 1
      elsif c.ord < 0x20
	newcol += 1
      end
      newcol += 1
      break if newcol > @@curgoal
      col = newcol
      dbo += 1
    end
    return dbo
  end

  # Move forward by full lines.
  # If the number of lines to move is less
  # than zero, call the backward line function to
  # actually do it. The last command controls how
  # the goal column is set.  Return TRUE if the
  # move was actually performed; FALSE otherwise
  # (e.g., if we were already on the last line).
  def forwline(f : Bool, n : Int32, k : Int32) : Result
    if n < 0
      return backline(f, -n, Kbd::RANDOM)
    end

    # Get the current line pointer.
    w = E.curw
    dot = w.dot
    b = w.buffer
    bsize = b.size
    unless lp = b[dot.l]
      raise "Nil lp in forwline!"
    end

    # If the last command was not forwline or backline,
    # set the goal column to the offset of the dot.
    if !E.lastflag.cpcn?
      setgoal(lp, dot.o)
    end
    E.thisflag = E.thisflag | Eflags::Cpcn

    # If we're already on the last line, do nothing.
    if dot.l == bsize - 1
      return Result::True
    end

    # Move dot to next line.
    dot.l += 1
    lp = lp.next
    dot.o = getgoal(lp)
    w.flags |= Wflags::Move

    return Result::True
  end

  # This function is like "forwline", but
  # goes backwards. The scheme is exactly the same.
  # Check for arguments that are less than zero and
  # call your alternate. Figure out the new line and
  # call "movedot" to perform the motion.  Return TRUE if the
  # move was actually performed; FALSE otherwise
  # (e.g., if we were already on the first line).
  def backline(f : Bool, n : Int32, k : Int32) : Result
    if n < 0
      return forwline(f, -n, Kbd::RANDOM)
    end

    # Get the current line pointer.
    w = E.curw
    dot = w.dot
    b = w.buffer
    unless lp = b[dot.l]
      raise "Nil lp in backline!"
    end

    # If the last command was not forwline or backline,
    # set the goal column to the offset of the dot.
    if !E.lastflag.cpcn?
      setgoal(lp, dot.o)
    end
    E.thisflag = E.thisflag | Eflags::Cpcn

    # If we're already on the first line, do nothing.
    if dot.l == 0
      return Result::True
    end

    # Move dot to previous line.
    dot.l -= 1
    lp = lp.previous
    dot.o = getgoal(lp)
    w.flags |= Wflags::Move

    return Result::True
  end

  # Sets the mark in the current window.
  def setmark(f : Bool, n : Int32, k : Int32) : Result
    w = E.curw
    w.mark = w.dot.dup
    Echo.puts("[Mark set]")
    return Result::True
  end

  # Swaps the values of dot and mark in the current window.
  def swapmark(f : Bool, n : Int32, k : Int32) : Result
    w = E.curw
    dot = w.dot.dup
    mark = w.mark.dup
    if mark.l == -1
      Echo.puts("No mark in this window")
      return Result::False
    end
    w.mark = dot
    w.dot = mark
    return Result::True
  end

  # Binds keys for basic commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd::PGDN, cmdptr(forwpage), "forw-page")
    k.add(Kbd::PGUP, cmdptr(backpage), "back-page")
    k.add(Kbd::RIGHT, cmdptr(forwchar), "forw-char")
    k.add(Kbd::LEFT, cmdptr(backchar), "back-char")
    k.add(Kbd::HOME, cmdptr(gotobol), "goto-bol")
    k.add(Kbd::KEND, cmdptr(gotoeol), "goto-eol")
    k.add(Kbd.meta('<'), cmdptr(gotobob), "goto-bob")
    k.add(Kbd.meta('>'), cmdptr(gotoeob), "goto-eob")
    k.add(Kbd::DOWN, cmdptr(forwline), "forw-line")
    k.add(Kbd::UP, cmdptr(backline), "back-line")
    k.add(Kbd.ctrl('@'), cmdptr(setmark), "set-mark")
    k.add(Kbd.ctlx_ctrl('x'), cmdptr(swapmark), "swap-dot-and-mark")

    k.add_dup(Kbd.ctrl('v'), "forw-page")
    k.add_dup(Kbd.ctrl('z'), "back-page")
    k.add_dup(Kbd.ctrl('f'), "forw-char")
    k.add_dup(Kbd.ctrl('b'), "back-char")
    k.add_dup(Kbd.ctrl('a'), "goto-bol")
    k.add_dup(Kbd.ctrl('e'), "goto-eol")
    k.add_dup(Kbd.ctrl('n'), "forw-line")
    k.add_dup(Kbd.ctrl('p'), "back-line")
  end
end
