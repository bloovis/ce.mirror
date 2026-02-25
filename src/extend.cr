# `Extend` contains a command for running a command by name (useful for
# commands that aren't bound to a key), and a command for displaying the
# command bound to a key.
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
  # command bound to that key.  If the key is F1, display
  # a popup window showing some common key bindings.
  def help(f : Bool, n : Int32, k : Int32) : Result
    k = E.kbd.getkey
    if k == Kbd::F1
      b = Buffer.sysbuf
      b.clear
      s = <<-EOS
      Some commonly used key bindings:
      F1: wait for a key, then display the command bound to that key
      Ctrl-X Ctrl-K: display all key bindings
      Ctrl-X Ctrl-S or F2: save current file
      Ctrl-X Ctrl-V or F3: open a file
      Ctrl-X Ctrl-C or F4: exit the editor
      Ctrl-X 2: split the window
      Ctrl-X N: move to the next window
      Ctrl-X 1: make the current window the only window
      F8: move to the next buffer
      F5: undo
      EOS
      s.lines.each {|l| b.addline l}
      return b_to_r(Buffer.popsysbuf)
    end

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
