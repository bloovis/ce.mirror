require "./ce"

# `Echo` contains routines for reading and writing characters in
# the so-called echo line area, the bottom line of the screen.
module Echo

  @@noecho = false

  extend self

  # Sets the `@@noecho` boolean to *x*.
  def self.noecho=(x : Bool)
    @@noecho = x
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

  # Writes the string *s* to the echo line.
  def self.puts(s : String)
    tty = E.tty
    tty.putline(tty.nrow - 1, 0, s)
  end

  # Erases the echo line.
  def self.erase
    tty = E.tty
    tty.move(tty.nrow - 1, 0)
    tty.eeol
  end

end
