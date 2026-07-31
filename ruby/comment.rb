# comment.rb

# MicroEMACS function for reformatting a Ruby, Perl, or C comment.

# Calculate number of columns in a string, taking tabs into account.

def columns(s)
  w = 0
  ts = E.tabsize
  s.each_char do |c|
    if c == "\t"
      w += ts - w % ts
    else
      w += 1
    end
  end
  return w
end

# Reformat a Ruby/Perl comment.

def formatrubycomment(n)
  # The dot must be in the first line of a comment.
  # Extract the leading spaces so we know how much
  # to indent each line.
  if E.line =~ /^(\s*)(.*)/
    spc = $1
    rest = $2
    if rest[0] != '#'
      E.echo "This line does not look like a Ruby or Perl comment"
      return EFALSE
    end
  end

  # Collect the text of each paragraph in the comment.
  E.goto_bol
  E.set_mark
  paras = []
  para = ''
  while E.line =~ /^\s*#\s*(.*)/
    rest = $1
    if rest.length == 0
      paras << para
      para = ''
    end
    para << rest + '  '
    if forw_line != ETRUE
      E.goto_eol
      break
    end
  end
  if para.length > 0
    paras << para 
  end

  # Kill the existing comment.
  E.kill_region

  # Reconstruct the comment, ensuring that the paragraphs don't
  # go past the fill column.
  maxlen = E.fillcol - 2 - columns(spc)
  leader = spc + '# '
  paras.each_with_index do |para, i|
    words = para.split
    line = ''
    words.each do |word|
      if line.length + 1 + word.length > maxlen
	E.insert leader + line + "\n"
	line = word
      else
	if line.length == 0
	  line << word
	else
	  line << ' ' + word
	end
      end
    end
    if line.length > 0
      E.insert leader + line + "\n"
    end
    if i != paras.length - 1
      E.insert leader + "\n"
    end
  end
  E.echo '[Comment reformatted]'
  return ETRUE
end

# Reformat a C comment.  TODO: C++ comments (//).

def formatccomment(n)
  # The dot must be in the first line of a comment.
  # Extract the leading spaces so we know how much
  # to indent each line.
  unless E.line =~ /^\s*\/\*/
    E.echo "This line does not look like start of C comment"
    return EFALSE
  end

  # Collect the text of each paragraph in the comment.
  E.goto_bol
  E.set_mark
  paras = []
  para = ''
  keepgoing = true
  spc = ''
  while keepgoing
    line = E.line
    if line =~ /^(\s*)\/\*\s*(.*)\*\//		# comment start and end: /* ... */
      spc = $1
      rest = $2
      keepgoing = false
    elsif line =~ /^(\s*)\/\*\s*(.*)/		# comment start: /*
      spc = $1
      rest = $2
    elsif line =~ /^\s*\*?\s*(.*)\*\//		# comment end: */
      keepgoing = false
      rest = $1
    elsif line =~ /^\s*\*?\s*(.*)\s*$/		# comment middle: *
      rest = $1
    else
      rest = line
    end   
    if rest.length == 0
      if para.length > 0
	paras << para
      end
      para = ''
    else
      para << rest + '  '
    end
    if E.forw_line != ETRUE
      E.goto_eol
      break
    end
  end
  if para.length > 0
    paras << para 
  end

  # Kill the existing comment.
  E.kill_region

  # Reconstruct the comment, ensuring that the paragraphs don't
  # go past the fill column.
  maxlen = E.fillcol - 3 - columns(spc)
  leader = spc + '/* '
  paras.each_with_index do |para, i|
    words = para.split
    line = ''
    words.each do |word|
      if line.length + 1 + word.length > maxlen
	E.insert leader + line + "\n"
	leader = spc + ' * '
	line = word
      else
	if line.length == 0
	  line << word
	else
	  line << ' ' + word
	end
      end
    end
    if line.length > 0
      E.insert leader + line + "\n"
      leader = spc + ' * '
    end
    if i != paras.length - 1
      E.insert leader + "\n"
      leader = spc + ' * '
    end
  end
  E.insert spc + ' */' + "\n"
  E.echo "[Comment reformatted]"
  return ETRUE
end

def formatcomment(n)
  line = E.line
  if line =~ /^\s*#/
    return formatrubycomment(n)
  elsif line =~ /^\s*\/\*/
    return formatccomment(n)
  else
    E.echo "Line doesn't contain start of Ruby or C comment"
    return EFALSE
  end
end

# Tell MicroEMACS about the new command.

E.ruby_command "formatcomment"
E.bind "formatcomment", meta(';')
