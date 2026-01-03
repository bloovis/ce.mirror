require "./spec_helper"
require "../src/keymap"

module Values
  @@values = {false, 0, ""}

  def self.values
    @@values
  end

  def self.set_values(t)
    @@values = t
  end
end

def pagedown(f : Bool, n : Int32, k : String) : Result
  puts "pagedown: f #{f}, n #{n}, k #{k}"
  Values.set_values({f, n, k})
  return Result::True
end

def pageup(f : Bool, n : Int32, k : String) : Result
  puts "pageup: f #{f}, n #{n}, k #{k}"
  Values.set_values({f, n, k})
  return Result::False
end

macro cmdptr(name)
  ->{{name}}(Bool, Int32, String)
end

describe KeyMap do
  k = KeyMap.new

  it "Creates a one-key map" do
    k.add("PgDn", cmdptr(pagedown), "down-page")
    result = k.call_by_key("PgDn", true, 42)
    result.should eq(Result::True)
    Values.values.should eq({true, 42, "PgDn"})

    result = k.call_by_key("PgDn", false, 1066)
    result.should eq(Result::True)
    Values.values.should eq({false, 1066, "PgDn"})

    result = k.call_by_name("down-page", true, 2001, "none")
    result.should eq(Result::True)
    Values.values.should eq({true, 2001, "none"})
  end

  it "Adds a second entry to the map" do
    k.add("PgUp", cmdptr(pageup), "up-page")
    result = k.call_by_key("PgUp", true, 1776)
    result.should eq(Result::False)
    Values.values.should eq({true, 1776, "PgUp"})

    result = k.call_by_key("PgUp", false, 1492)
    result.should eq(Result::False)
    Values.values.should eq({false, 1492, "PgUp"})

    result = k.call_by_name("up-page", true, 1945, "weird")
    result.should eq(Result::False)
    Values.values.should eq({true, 1945, "weird"})
  end

  it "Tries to call an unbound method" do
    result = k.call_by_key("PgUp", false, -99)
    result.should eq(Result::False)
  end

end
