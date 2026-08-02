# Ruby extension for running a command (a gcc or Crystal compilation)
# and using the error output to load sources of the errors.
# "C-x x" prompts for the command, runs it, and reads the errors.
# "M-C-e" finds the next error and loads the source of the error.

require 'open3'

def gccerr(n)
  E.forw_window
  keepgoing = true
  while keepgoing
    l = E.line
    founderror = false
    f = ""
    lno = 0
    col = 0
    err = ""
    if l !~ /^In file included/ && l =~ /(.*):(\d+):(\d+): (.*)/
      # This is a gcc error.
      file = $1
      lno = $2
      col = $3
      err = $4
      founderror = true
    elsif l =~ /^In ([^:]+):(\d+):(\d+)/
      # This is a Crystal error.
      file = $1
      lno = $2
      col = $3
      looking = true
      while looking
	if E.forw_line == ETRUE
	  l = E.line
	  if l =~ /^Error:\s*(.*)/
	    err = $1
	    looking = false
	    founderror = true
	  end
	else
	  looking = false
	  keepgoing = false
	end
      end
    end
    if founderror
      E.forw_line
      E.forw_window
      if File.exist? file
	E.file_visit file
	E.goto_line lno.to_i
	E.forw_char col.to_i - 1
	E.echo "#{err}"
        return ETRUE
      else
	E.echo "File #{file} does not exist"
        return EFALSE
      end
    end
    keepgoing = E.forw_line == ETRUE
  end
  E.forw_window
  E.echo "No more errors"
  return EFALSE
end

$old_cmd = ""

def xec(n)
  # Prompt for a command and run it.
  cmd = E.reply "Enter a command [#{$old_cmd}]: "
  unless cmd
    return EFALSE
  end
  if cmd == ""
    cmd = $old_cmd
  else
    $old_cmd = cmd
  end
  if cmd == ""
    E.echo "You must enter a non-blank command."
    return EFALSE
  end

  E.echo("Running #{cmd}...")
  E.update
  stdout_str, stderr_str, status = Open3.capture3(cmd)

  # Open the special buffer in a second window, and clear it.
  E.only_window
  E.split_window
  E.forw_window
  E.use_buffer '*output*'
  E.goto_bob
  E.set_mark
  E.goto_eob
  E.kill_region

  # Insert the output of the command
  E.insert("stdout:\n");
  E.insert("-------\n");
  E.insert(stdout_str);
  E.insert("stderr:\n");
  E.insert("-------\n");
  E.insert(stderr_str);
  E.goto_bob
  E.bflag = 0

  # Switch back to our original window.
  E.forw_window

  if status.to_i != 0
    E.echo "Error: #{status}"
    return EFALSE
  else
    E.echo "Success!"
    return ETRUE
  end
end

E.ruby_command "gccerr"
E.bind "gccerr", metactrl('e')

E.ruby_command "xec"
E.bind "xec", ctlx('x')
