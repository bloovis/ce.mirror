enum Result
  False
  True
  Abort
end

# Convert true to Result::True, and false to Result::False
# to false.
def b_to_r(b : Bool) : Result
  b ? Result::True : Result::False
end

# Converts the name of a command method to a Proc object.
macro cmdptr(name)
  ->{{name}}(Bool, Int32, Int32)
end

# `KeyMap` implements a hash associating keystrokes with command methods.
class KeyMap
  @@unbound = -1	# negative key values are used for unbound commands

  alias CmdProc = Proc(Bool, Int32, Int32, Result)	# cmd(f, n, k) returns Result
  property k2p = {} of Int32  => CmdProc	# key  => command method
  property n2p = {} of String => CmdProc	# name => command method
  property k2n = {} of Int32  => String		# key  => name

  def initialize
  end

  # Adds a mapping for the key *key) to the command *proc*, whose
  # name is *name*.  If the key is KRANDOM, the command is actually
  # not bound to a key, so use a unique magic negative number for the key.
  def add(key : Int32 | Char, proc : CmdProc, name : String)
    if key.is_a?(Char)
      key = key.ord
    elsif key == Kbd::RANDOM
      key = @@unbound
      @@unbound -= 1
    end
    @k2p[key] = proc
    @n2p[name] = proc
    @k2n[key] = name
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
      @k2n[key] = name
    else
      raise "Command '#{name}' does not exist!"
    end
  end

  # Binds the key *key* to the Ruby command *name*.
  def addruby(key : Int32, name : String)
    add(key, ->(f : Bool, n : Int32, k : Int32) {
             RubyRPC.rubycall(name, f, n, key) },
	name)
  end

  # Returns true if there is a command bound to the key *key*.
  def key_bound?(key : Int32) : Bool
    if key.is_a?(Char)
      key = key.ord
    end
    @k2p.has_key?(key)
  end

  # Calls the command method bound to the key *bindkey*, passing it
  # the arguments *f*, *n*, and *k*.
  def call_by_key(bindkey : Int32, f : Bool, n : Int32, key : Int32) : Result
    if key_bound?(bindkey)
      return @k2p[bindkey].call(f, n, key)
    else
      #STDERR.puts "No command bound to key #{bindkey}"
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
      Echo.puts("Unknown command #{name}")
      return Result::False
    end
  end
end
