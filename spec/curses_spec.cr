require "./spec_helper"
require "../src/curses"

def start_cursing : LibNCurses::Window
  scr = LibNCurses.initscr
  LibNCurses.noecho           # turn off input echoing
  LibNCurses.raw              # don't let Ctrl-C generate a signal
  LibNCurses.nonl             # turn off newline translation
  #LibNCurses.stdscr.intrflush(false) # turn off flush-on-interrupt
  LibNCurses.keypad(scr, true)     # turn on keypad mode
  return scr
end

def end_cursing
  LibNCurses.echo
  LibNCurses.nocbreak
  LibNCurses.nl
  LibNCurses.endwin
end

describe Object do

  scr : LibNCurses::Window

  it "Tests Ncurses" do
    nrows = `tput lines`.chomp.to_i
    ncols = `tput cols`.chomp.to_i
    scr = start_cursing

    maxy = LibNCurses.getmaxy(scr)
    maxx = LibNCurses.getmaxx(scr)
    LibNCurses.wmove(scr, 0, 0)
    LibNCurses.waddstr(scr, "Please hit the Home key: ")
    LibNCurses.wget_wch(scr, out key)

    end_cursing

    nrows.should eq(maxy)
    ncols.should eq(maxx)
    key.should eq(LibNCurses::KEY_HOME)
  end
end

