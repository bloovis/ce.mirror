# `Extend` contains commands for dealing with macros and key bindings.
module Extend

  extend self

  def extendedcommand(f : Bool, n : Int32, k : Int32) : Result
    result, name = Echo.reply_with_completions(": ", nil, true) do |s|
      # Find all command names that start with s.
      E.keymap.n2p.keys.select {|key| key.starts_with?(s)}
    end

    # Return immediately on Ctrl-G abort.
    return result if result != TRUE

    return E.keymap.call_by_name(name, f, n, k)
  end

    # Creates key bindings for all Extend commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.meta('x'), cmdptr(extendedcommand), "extended-command")
  end

end
