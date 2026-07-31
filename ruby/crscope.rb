# This editor extension provides an interface to crscope, the cscope-like utility
# for searching and browsing Crystal and Ruby code.  Crscope can be found
# in the csup repository.

F11    = 0x95	# FIXME: this should be moved to server.rb, along with the other F keys

#search = ARGV[0]

# Read and ignore the prompt from crscope.
def get_prompt(io)
  c1 = io.getc
  c2 = io.getc
  c3 = io.getc
  s = [c1, c2, c3].join("")
  if s == ">> "
    #puts "Got valid prompt"
  else
    #puts "Invalid prompt #{s}!"
  end
end

# Invoke crscope in a pipe to get the results of a search.
# Return the results as an array of strings formatted to
# display nicely.
def do_search(io, search)
  a = []
  get_prompt(io)
  E.echo "Sending #{search}"
  io.puts search
  s = io.gets
  if s =~ /^cscope: (\d+)/
    hits = $1.to_i
    #puts "#{hits} hits"
    filenames = []
    symbols = []
    lines = []
    contexts = []
    flen = 0
    slen = 0
    hits.times do |i|
      s = io.gets.chomp
      E.echo "Got '#{s}'"
      if s =~ /^(\S+) (\S+) (\S+) (.+)$/
	filenames << $1
	flen = [flen, $1.size].max
	symbols << $2
	slen = [slen, $2.size].max
	lines << $3.to_i
	contexts << $4
      end
    end
    #puts "Max filename length: #{flen}"
    #puts "Max symbol length: #{slen}"
    hits.times do |i|
      s = sprintf "%5d %-*s %-*s %5d %s",
	     i,
	     flen, filenames[i],
	     slen, symbols[i],
	     lines[i],
	     contexts[i]
      a << s
    end
  end
  return a
end

# Open crscope in a read/write pipe, and return the file handle.
def open_crscope
  return IO.popen(["crscope", "-l"], mode="r+")
end

# Close the crscope pipe handle.
def close_crscope(io)
  get_prompt(io)
  io.close
end

# Open the file indicated by the current line in the crscope results buffer,
# and move to the indicated line number.
def visitfile(n)
  # Extract the filename and line number from the current crscope results line.
  line = E.line
  if line =~ /\s*\d*\s*(\S+)\s*\S+\s*(\d+)/
    filename = $1
    lineno = $2
  else
    E.echo "Invalid crsope result line"
    return EFALSE
  end

  # Split the window, and read the file into the other window.
  E.only_window
  E.split_window
  E.forw_window
  E.file_visit filename
  E.goto_line lineno
  return ETRUE
end

# Call crscope to get the results of the search *str*.  Then
# open a special read-only buffer showing the results.  In this buffer,
# hitting return will open the file indicated on that line.
def showresults(str)
  # Get the results array.
  io = open_crscope
  a = do_search(io, str)
  close_crscope(io)

  # Write the results to the crscope buffer.
  E.only_window
  E.use_buffer '*crscope*'
  E.bflag = 0
  E.goto_bob
  E.set_mark
  E.goto_eob
  E.kill_region
  a.each { |s| E.insert s + "\n" }
  E.goto_bob

  # Make the buffer readonly, attach a mode to it, and bind
  # the Enter key to the command that opens the selected file.
  E.bflag = BFRO
  E.setmode "crscope"
  E.bind "visitfile", ctrl('m'), true

  return ETRUE
end

# This command prompts the user for a search type and string, then
# displays the results of the search.
def crscope(n)
  # Prompt for a search type.
  type = E.reply "Search type (0=symbol,1=def,2=calls by,3=calls to,4=text,6=grep,7=file,8=assign): "

  # Prompt for a string to search.
  str = E.reply "Search string: "
  unless str
    return EFALSE
  end
  return showresults type+str
end

E.ruby_command "crscope"
E.ruby_command "visitfile"
E.bind "crscope", F11
