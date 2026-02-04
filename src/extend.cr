# `Extend` contains commands for dealing with macros and key bindings.
module Extend

  extend self

  # Prompts the user for a command name, and runs that command.
  def extendedcommand(f : Bool, n : Int32, k : Int32) : Result
    result, name = Echo.reply_with_completions(": ", nil, true) do |s|
      # Find all command names that start with s.
      E.keymap.n2p.keys.select {|key| key.starts_with?(s)}
    end

    # Return immediately on Ctrl-G abort.
    return result if result != TRUE

    return E.keymap.call_by_name(name, f, n, k)
  end

  # Waits for the user to hit a key, then shows the name of the
  # command bound to that key
  def help(f : Bool, n : Int32, k : Int32) : Result
    k = E.kbd.getkey
    name = E.keymap.k2n[k]?
    if name
      Echo.puts("[#{Kbd.keyname(k)} is bound to #{name}]")
    else
      Echo.puts("[#{Kbd.keyname(k)} is unbound]")
    end
    return TRUE
  end

    # Creates key bindings for all Extend commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd.meta('x'), cmdptr(extendedcommand), "extended-command")
    k.add(Kbd::F1, cmdptr(help), "help")
  end

end
