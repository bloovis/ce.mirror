require "./spec_helper"
require "../src/terminal"

def start_cursing : Terminal
  tty = Terminal.new
  tty.open
  return tty
end

def end_cursing(tty : Terminal)
  tty.close
end

describe Object do

  scr : LibNCurses::Window

  it "Tests Ncurses" do
    nrows = `tput lines`.chomp.to_i
    ncols = `tput cols`.chomp.to_i
    tty = start_cursing

    maxy = tty.nrow
    maxx = tty.ncol
    tty.move(0, 0)
    tty.puts("Please hit the Home key: ")
    key = tty.getc

    end_cursing(tty)

    nrows.should eq(maxy)
    ncols.should eq(maxx)
    key.should eq(Kbd::HOME)
  end
end

