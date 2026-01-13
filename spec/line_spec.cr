require "./spec_helper"
require "../src/line"
require "../src/buffer"
require "../src/window"
require "../src/terminal"
require "../src/keymap"
require "../src/display"
require "../src/e"

def initial_setup
  Line.insert("This is line one.")
  Line.newline
  Line.insert("This is line two.")
  Line.newline
  Line.insert("This is line three.")
  Line.newline
end

describe Buffer do
  # Create a buffer with a single empty line.
  e = E.new
  e.tty.close
  b = Buffer.new("dummy")
  w = Window.new(b)

  it "Creates an initial buffer" do
    initial_setup

    lineno = 1
    b.each do |s|
      case lineno
      when 1
        s.text.should eq "This is line one."
	s.should eq(b.first_line)
      when 2
        s.text.should eq "This is line two."
      when 3
	s.text.should eq "This is line three."
      when 4
        s.text.should eq ""
	s.should eq(b.last_line)
      end
      lineno += 1
    end
    b.size.should eq(4)
  end

  it "Prepends some text to the first line" do
    w.dot = Pos.new(0, 0)
    Line.insert("Text before ")
    if lp = b[0]
      lp.text.should eq("Text before This is line one.")
    else
      lp.nil?.should eq(false)
    end
  end

  it "Appends some text to the second line" do
    if lp = b[1]
      w.dot = Pos.new(1, lp.text.size)
      Line.insert(" text after")
      lp.text.should eq("This is line two. text after")
    else
      lp.nil?.should eq(false)
    end
  end

  it "Inserts some text in the third line" do
    w.dot = Pos.new(2, 8)
    Line.insert("text inside ")
    if lp = b[2]
      lp.text.should eq("This is text inside line three.")
    else
      lp.nil?.should eq(false)
    end
  end
end
