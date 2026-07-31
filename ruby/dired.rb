# dired.rb

require 'open3'
#require '/usr/local/share/pe/pe.rb'

$nameoffset = 46

def viewfile(filename, kind)
  # Check that the file is plain text.
  stdout_s, status = Open3.capture2('file', '-b', '--mime-type', filename)
  str = stdout_s.chomp
  if status.to_i != 0
    E.echo str
    return EFALSE
  end
  unless str =~ /^text\//
    if E.reply("#{filename} is not text.  Hit enter to continue: ") == nil
      return EFALSE
    end
  end
  case kind
  when :visit
    E.file_visit filename
  when :open
    E.only_window
    E.split_window
    E.forw_window
    E.file_visit filename
  when :display
    E.only_window
    E.split_window
    E.forw_window
    E.file_visit filename
    E.back_window
  end
  return ETRUE
end

def showdir(dir)
  # Switch to the dired buffer and destroy any existing content.
  E.use_buffer '*dired*'
  E.bflag = 0
  E.goto_bob
  E.set_mark
  E.goto_eob
  E.kill_region

  # Insert the contents of the directory, and move
  # the dot to the first entry other than . or ..
  fulldir = File.expand_path(dir)
  output, stderr_str, status = Open3.capture3('ls', '-laF', fulldir)
  if status != 0
    echo "Unable to open directory"
    return EFALSE
  end
  stderr_str += ""	# suppress warning about unused variable
  E.insert fulldir + ":\n"
  E.insert output

  # Figure out the offset of the filename in each line.
  E.lineno = 3
  l = E.line
  if l =~ /^(.*)\.\//
    $nameoffset = $1.length
  else
    $nameoffset = 46	# just a guess
  end
  E.lineno = 5
  E.offset = $nameoffset

  # Make the buffer readonly, attach a mode to it, and bind
  # some keys to special functions.
  E.bflag = BFRO
  E.setmode "dired"
  E.bind "visitfile", ctrl('m'), true
  E.bind "openfile", key('o'), true
  E.bind "displayfile", ctrl('o'), true
  return ETRUE
end

def handlefile(kind)
  line = E.line.chomp
  if E.lineno == 1
    # Extract the portion of the path up to next / after the cursor on line 1
    line.gsub!(/:/, '')
    offset = E.offset
    after = line[offset..-1]
    if after =~ /^([^\/]*)\//
      afterlen = $1.length
      filename = line[1..offset+afterlen]
    else
      filename = line[1..-1]
    end
    dir = ''
  else
    # Extract the filename from the directory listing.
    if E.lineno < 3
      return EFALSE
    end
    old_lineno = E.lineno
    old_offset = E.offset
    E.goto_bob
    dir = E.line[0..-3]
    E.lineno = old_lineno
    E.offset = old_offset
    filename = line[$nameoffset..-1]
    filename.gsub!(/\*/, '')		# executable file
    filename.gsub!(/ -> .*/, '')	# symbolic link
  end
  full = dir + '/' + filename
  if File.directory?(full)
    if full[-1] != '/'
      full << '/'
    end
    showdir(full)
  else
    viewfile(full, kind)
  end
end
  
def visitfile(n)
  handlefile :visit
end

def openfile(n)
  handlefile :open
end

def displayfile(n)
  handlefile :display
end

def dired(n)
  # Prompt for the directory name and expand it fully.
  dir = E.reply "Enter a directory name: "
  unless dir
    return EFALSE
  end
  return showdir(dir)
end

# Tell MicroEMACS about the new commands.

E.ruby_command "dired"
E.bind "dired", ctlx('d')
E.ruby_command "visitfile"
E.ruby_command "openfile"
E.ruby_command "displayfile"

#E.run
