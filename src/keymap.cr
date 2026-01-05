enum Result
  False
  True
  Abort
end

class KeyMap
  alias CmdProc = Proc(Bool, Int32, Int32, Result)	# cmd(f, n, k) returns Result
  property k2p = {} of Int32  => CmdProc
  property n2p = {} of String => CmdProc

  def initialize
  end

  def add(key : Int32, proc : CmdProc, name : String)
    @k2p[key] = proc
    @n2p[name] = proc
  end

  def key_bound?(key : Int32) : Bool
    @k2p.has_key?(key)
  end

  def call_by_key(key : Int32, f : Bool, n : Int32) : Result
    if key_bound?(key)
      @k2p[key].call(f, n, key)
    else
      puts "No command bound to key #{key}"
      return Result::False
    end
  end

  def name_bound?(name : String) : Bool
    @n2p.has_key?(name)
  end

  def call_by_name(name : String, f : Bool, n : Int32, k : Int32) : Result
    if name_bound?(name)
      @n2p[name].call(f, n, k)
    else
      puts "No command called #{name}"
      return Result::False
    end
  end
end
