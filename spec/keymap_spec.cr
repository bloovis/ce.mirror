require "./spec_helper"
require "../src/keymap"
require "../src/keyboard"

module Values
  @@values = {false, 0, 0}

  def self.values
    @@values
  end

  def self.set_values(t)
    @@values = t
  end
end

def pagedown(f : Bool, n : Int32, k : Int32) : Result
  puts "pagedown: f #{f}, n #{n}, k #{k}"
  Values.set_values({f, n, k})
  return Result::True
end

def pageup(f : Bool, n : Int32, k : Int32) : Result
  puts "pageup: f #{f}, n #{n}, k #{k}"
  Values.set_values({f, n, k})
  return Result::False
end

macro cmdptr(name)
  ->{{name}}(Bool, Int32, Int32)
end

describe KeyMap do
  k = KeyMap.new

  it "Creates a one-key map" do
    k.add(Kbd::PGDN, cmdptr(pagedown), "down-page")
    result = k.call_by_key(Kbd::PGDN, true, 42)
    result.should eq(Result::True)
    Values.values.should eq({true, 42, Kbd::PGDN})

    result = k.call_by_key(Kbd::PGDN, false, 1066)
    result.should eq(Result::True)
    Values.values.should eq({false, 1066, Kbd::PGDN})

    result = k.call_by_name("down-page", true, 2001, Kbd::RANDOM)
    result.should eq(Result::True)
    Values.values.should eq({true, 2001, Kbd::RANDOM})
  end

  it "Adds a second entry to the map" do
    k.add(Kbd::PGUP, cmdptr(pageup), "up-page")
    result = k.call_by_key(Kbd::PGUP, true, 1776)
    result.should eq(Result::False)
    Values.values.should eq({true, 1776, Kbd::PGUP})

    result = k.call_by_key(Kbd::PGUP, false, 1492)
    result.should eq(Result::False)
    Values.values.should eq({false, 1492, Kbd::PGUP})

    result = k.call_by_name("up-page", true, 1945, Kbd::RANDOM)
    result.should eq(Result::False)
    Values.values.should eq({true, 1945, Kbd::RANDOM})
  end

  it "Tries to call an unbound method" do
    result = k.call_by_key(Kbd::DOWN, false, -99)
    result.should eq(Result::False)
  end

end
