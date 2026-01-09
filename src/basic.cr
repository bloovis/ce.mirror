require "./ce.cr"

# `Basic` contains basic command functions for moving the
# cursor around on the screen, setting mark, and swapping dot with
# mark. Only moves between lines, which might make the
# current buffer framing bad, are hard.
module Basic
  @@curgoal = 0

  extend self

  # Checks if the dot must move after the current window has been
  # scrolled by forw-page or back-page.
  def checkdot(w : Window)
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
    n = page unless f
    
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
    n = page unless f
    if n < 0
      return forwpage(f, -n, Kbd::RANDOM)
    end
      
    # Move the current line number up, but not past the start of the buffer.
    w.line -= n
    w.line = 0 if w.line < 0

    # This is a hard update (i.e., entire window must be redrawn).
    w.flags |= Wflags::Hard

    checkdot(w)
    return Result::True
  end

  # Binds keys for basic commands.
  def self.bind_keys(k : KeyMap)
    k.add(Kbd::PGDN, cmdptr(forwpage), "forw-page")
    k.add(Kbd::PGUP, cmdptr(backpage), "back-page")
    k.add_dup(Kbd.ctrl('v'), "forw-page")
    k.add_dup(Kbd.ctrl('z'), "back-page")
  end
end
