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
      b.flags = b.flags & ~Bflags::Changed
      return Result::True
    else
      return Result::False
    end
  end

  # Creates key bindings for all Files commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.ctlx_ctrl('q'), cmdptr(togglereadonly), "ins-self")
    k.add(Kbd.ctlx_ctrl('s'), cmdptr(filesave), "file-save")
  end

end
