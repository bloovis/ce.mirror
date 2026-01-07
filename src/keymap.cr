enum Result
  False
  True
  Abort
end


# Converts the name of a command method to a Proc object.
macro cmdptr(name)
  ->{{name}}(Bool, Int32, Int32)
end

# `KeyMap` implements a hash associating keystrokes with command methods.
class KeyMap
  alias CmdProc = Proc(Bool, Int32, Int32, Result)	# cmd(f, n, k) returns Result
  property k2p = {} of Int32  => CmdProc
  property n2p = {} of String => CmdProc

  def initialize
  end

  # Adds a mapping for the key *key) to the command *proc*, whose
  # name is *name*.
  def add(key : Int32 | Char, proc : CmdProc, name : String)
    if key.is_a?(Char)
      key = key.ord
    end
    @k2p[key] = proc
    @n2p[name] = proc
  end

  # Adds a mapping for the key *key* to the command with the name *name*,
  # which must have already been bound to another key.
  def add_dup(key : Int32 | Char, name : String)
    if key.is_a?(Char)
      key = key.ord
    end
    proc = @n2p[name]?
    if proc
      @k2p[key] = proc
    else
      raise "Command '#{name}' does not exist!"
    end
  end

  # Returns true if there is a command bound to the key *key*.
  def key_bound?(key : Int32) : Bool
    if key.is_a?(Char)
      key = key.ord
    end
    @k2p.has_key?(key)
  end

  # Calls the command method bound to the key *key*, passing it
  # the arguments *f* and *n*, along with the *key* that invoked it.
  def call_by_key(key : Int32, f : Bool, n : Int32) : Result
    if key_bound?(key)
      @k2p[key].call(f, n, key)
    else
      puts "No command bound to key #{key}"
      return Result::False
    end
  end

  # Returns true if a command named *name* is bound to a key.
  def name_bound?(name : String) : Bool
    @n2p.has_key?(name)
  end

  # Calls the command method named *name*, passing it
  # the arguments *f*, *n*, and *k*.
  def call_by_name(name : String, f : Bool, n : Int32, k : Int32) : Result
    if name_bound?(name)
      @n2p[name].call(f, n, k)
    else
      puts "No command called #{name}"
      return Result::False
    end
  end
end
