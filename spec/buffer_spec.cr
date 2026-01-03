require "./spec_helper"
require "../src/buffer"
require "../src/line"

def initial_setup(b : Buffer)
  line1p = Line.alloc("This is line one.")
  b.push(line1p)
  line2p = Line.alloc("This is line two.")
  b.push(line2p)
  line3p = Line.alloc("This is line three.")
  b.push(line3p)
end

describe Buffer do
  b = Buffer.new

  it "Creates an initial buffer" do
    initial_setup(b)

    lineno = 1
    b.each do |s|
      case lineno
      when 1
        s.text.should eq "This is line one."
      when 2
        s.text.should eq "This is line two."
      when 3
	s.text.should eq "This is line three."
      end
      lineno += 1
    end
  end

  line3p = nil
  it "Finds 'three'" do
    line3p = b.find {|l| l.text.includes?("three") }
    line3p.nil?.should eq(false)
  end

  it "Determines line number for line 3" do
    if line3p
      lnno = 0
      f = b.find {|l| lnno += 1; l == line3p}
      lnno.should eq 3
    end
  end

  it "Searches for non-existent string 'four'" do
    f = b.find {|l| l.text.includes?("four") }
    f.nil?.should eq(true)
  end

  line2p = Line.alloc("")	# dummy to prevent compile error later
  it "Seeks to line number 2" do
    lnno = 0
    f = b.find {|l| lnno += 1; lnno == 2}
    f.nil?.should eq(false)
    if f
      f.text.should eq "This is line two."
      line2p = f
    end
  end

  it "Seeks to non-existent line number 4" do
    lnno = 0
    f = b.find {|l| lnno += 1; lnno == 4}
    f.nil?.should eq(true)
  end

  l25p = Line.alloc("This is the new line 2.5.")
  it "Inserts a line after line 2" do
    l25p.nil?.should eq(false)
    b.insert_after(line2p, l25p)
    lineno = 1
    b.each do |s|
      case lineno
      when 1
	s.text.should eq "This is line one."
      when 2
	s.text.should eq "This is line two."
      when 3
	s.text.should eq "This is the new line 2.5."
      when 4
	s.text.should eq "This is line three."
      end
      lineno += 1
    end
  end

  it "Inserts a new line1.5 before line 2" do
    l15p = Line.alloc("This is the new line 1.5.")
    b.insert_before(line2p, l15p)
    lineno = 1
    b.each do |s|
      case lineno
      when 1
	s.text.should eq "This is line one."
      when 2
	s.text.should eq "This is the new line 1.5."
      when 3
	s.text.should eq "This is line two."
      when 4
	s.text.should eq "This is the new line 2.5."
      when 5
	s.text.should eq "This is line three."
      end
      lineno += 1
    end
  end

  it "Deletes line2" do
    b.delete (line2p)
    lineno = 1
    b.each do |s|
      case lineno
      when 1
	s.text.should eq "This is line one."
      when 2
	s.text.should eq "This is the new line 1.5."
      when 3
	s.text.should eq "This is the new line 2.5."
      when 4
	s.text.should eq "This is line three."
      end
      lineno += 1
    end
  end

  it "Modifies line 2.5 text" do
    l25p.text = "This is the replacement line 2.5."
    lineno = 1
    b.each do |s|
      case lineno
      when 1
	s.text.should eq "This is line one."
      when 2
	s.text.should eq "This is the new line 1.5."
      when 3
	s.text.should eq "This is the replacement line 2.5."
      when 4
	s.text.should eq "This is line three."
      end
      lineno += 1
    end
  end

  it "Inserts a line at the beginning" do
    line0p = Line.alloc("This is line zero.")
    b.unshift(line0p)
    b.head.should eq(line0p)

    lineno = 1
    b.each do |s|
      case lineno
      when 1
	s.text.should eq "This is line zero."
      when 2
	s.text.should eq "This is line one."
      when 3
	s.text.should eq "This is the new line 1.5."
      when 4
	s.text.should eq "This is the replacement line 2.5."
      when 5
	s.text.should eq "This is line three."
      end
      lineno += 1
    end
  end

  it "Test buffer flags" do
    b.flags = Bflags::Changed | Bflags::ReadOnly
    b.flags.read_only?.should eq(true)
    b.flags.changed?.should eq(true)
    b.flags = b.flags & ~Bflags::ReadOnly
    b.flags.read_only?.should eq(false)
    b.flags.changed?.should eq(true)
  end

end
