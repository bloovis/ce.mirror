require "./spec_helper"
require "../src/buffer"
require "../src/line"
require "../src/keymap"
require "../src/files"

def initial_setup(b : Buffer)
  b.list.clear
  b.addline("This is line one.")
  b.addline("This is line two.")
  b.addline("This is line three.")
end

describe Buffer do
  b = Buffer.new("dummy")

  it "Creates an initial buffer" do
    initial_setup(b)

    b.each_line do |lineno, s|
      case lineno
      when 0
        s.text.should eq "This is line one."
      when 1
        s.text.should eq "This is line two."
      when 2
	s.text.should eq "This is line three."
      end
    end
    b.size.should eq(3)
  end

  it "Iterates over three lines in a range" do
    count = 0
    seen = [] of Int32
    b.each_in_range(0,2) do |lineno, s|
      seen.push(lineno)
      case lineno
      when 0
        s.text.should eq "This is line one."
      when 1
        s.text.should eq "This is line two."
      when 2
	s.text.should eq "This is line three."
      end
      count.should eq(lineno)
      count += 1
      true	# tell each_in_range to continue
    end
    count.should eq(3)
    seen.size.should eq(3)
    seen[0].should eq(0)
    seen[1].should eq(1)
    seen[2].should eq(2)
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

  it "Uses [] to find line 3" do
    if line3p
      lp = b[2]
      lp.should eq(line3p)
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

  it "Uses [] to seek to line number 2" do
    f = b[1]
    f.nil?.should eq(false)
    if f
      f.text.should eq "This is line two."
    end
  end

  it "Seeks to non-existent line number 4" do
    lnno = 0
    f = b.find {|l| lnno += 1; lnno == 4}
    f.nil?.should eq(true)
  end

  it "Uses [] to seek to non-existent line number 4" do
    lnno = 0
    f = b[4]
    f.nil?.should eq(true)
  end

  l25p = Line.alloc("This is the new line 2.5.")
  it "Inserts a line after line 2" do
    l25p.nil?.should eq(false)
    line2p = b[1] || Line.alloc("Useless")
    line2p.nil?.should eq(false)
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
    b.size.should eq(4)
  end

  it "Inserts a new line1.5 before line 2" do
    l15p = Line.alloc("This is the new line 1.5.")
    line2p = b[1] || Line.alloc("Useless")
    b.list.insert_before(line2p, l15p)
    b.clear_caches(0)
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
    b.size.should eq(5)
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
    b.size.should eq(4)
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
    b.size.should eq(4)
  end

  it "Inserts a line at the beginning" do
    line0p = Line.alloc("This is line zero.")
    b.list.unshift(line0p)
    b.head.should eq(line0p)
    b.clear_caches(0)

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
    b.size.should eq(5)
  end

  it "Iterates over a sub-range" do
    lineno = 1
    seen = [] of Int32
    b.each_in_range(1, 3) do |n, s|
      seen.push(n)
      n.should eq(lineno)
      case lineno
      when 1
	s.text.should eq "This is line one."
      when 2
	s.text.should eq "This is the new line 1.5."
      when 3
	s.text.should eq "This is the replacement line 2.5."
      end
      lineno += 1
      true
    end
    lineno.should eq(4)
    seen.size.should eq(3)
    seen[0].should eq(1)
    seen[1].should eq(2)
    seen[2].should eq(3)
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
