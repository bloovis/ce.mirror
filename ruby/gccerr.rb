# Replacment for built-in gcc-error command.

#require '/usr/local/share/pe/pe.rb'

def gccerr(n)
  keepgoing = true
  while keepgoing
    l = E.line
    if (l !~ /^In file included/ && l =~ /(.*):(\d+):(\d+): (.*)/)
      file = $1
      lno = $2
      col = $3
      err = $4
      if File.exist? file
	E.forw_line
	E.only_window
	E.split_window
	E.forw_window
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
  E.echo "No more gcc errors"
  return EFALSE
end

E.ruby_command "gccerr"
E.bind "gccerr", metactrl('e')

# Run the event loop (only needed in RPC version of Ruby extensions).
#E.run
