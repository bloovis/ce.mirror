# These classes are used to parse and store information from one or more
# .editorconfig files.   For more information about these files, see
# <https://spec.editorconfig.org/> .

# The `ConfigSection` class stores information about a single section in
# a .editorconfig file.
class ConfigSection

  # The section name, which is a filepath glob.
  property glob = ""

  # The key/value pairs for the section.
  property pairs : Hash(String, String)

  # The fully expanded directory containing the associated
  # .editorconfig file.
  property dirname : String

  # The concatenation of dirname and glob, i.e., the
  # fully expanded glob pattern.
  property fullglob = ""

  # True if the the glob has a non-escaped forward slawh.
  property glob_has_slash : Bool

  def initialize(@glob, pathname)
    @pairs = Hash(String, String).new
    @dirname = File.dirname(pathname)
    @glob_has_slash = has_slash
    @fullglob = Path.new(@dirname, @glob).to_s
  end

  # Adds a key/value pair to the list, converting the key
  # to lowercase.
  def addpair(key : String, value : String)
    @pairs[key.downcase] = value
  end

  # Returns true if the glob has a non-escaped forward slash.
  private def has_slash : Bool
    brackets = false
    braces = false
    @glob.each_char do |c|
      if brackets
	if c == ']'
	  brackets = false
	end
      elsif braces
	if c == '}'
	  braces = false
	end
      else
	case c
	when '/'
	  return true
	when '['
	  brackets = true
	when '{'
	  braces = true
	end
      end
    end
    return false
  end
  
  # Extracts a bracket/brace group from glob, returns a tuple containing
  # the new glob and the group.
  private def get_group(glob : String, endchar : Char) : Tuple(String, String)
    s = ""
    i = 0
    while i < glob.size
      c = glob[i]?
      break unless c
      i += 1
      break if c == endchar
      s = s + c.to_s
    end
    return glob[i..], s
  end

  # Does the hard work of matching a string *name* against
  # a glob pattern *glob*.  Uses recursion heavily.
  private def do_match(glob : String, name : String) : Bool
    #STDERR.puts "do_match: glob '#{glob}', name '#{name}'"
    return true if glob.size == 0 && name.size == 0
    g = glob[0]?
    return false unless g
    case g
    when '*'
      if glob.size > 1 && glob[1] == '*'
	slash = 0.chr
	glob = glob[1..]
      else
	slash = '/'
      end
      i = 0
      while i < name.size && name[i] != slash
	return true if do_match(glob[1..], name[i..])
	i += 1
      end
      #STDERR.puts "star: glob #{glob}, name #{name}, i #{i}"
      if glob.size == 1
	# Nothing in the glob after '*', and we reached
	# the end of the name, so there is a match.
	return true
      else
	# We reached the end of the name, and there is
	# more to the glob, so try the rest of the glob.
	return do_match(glob[1..], name)
      end
    when '?'
      return do_match(glob[1..], name[1..])
    when '['
      glob, str = get_group(glob[1..], ']')
      #STDERR.puts "bracket: new glob '#{glob}', group '#{str}'"
      n = name[0]?
      return false unless n
      return false if !str.includes?(n)
      #STDERR.puts "bracket: matched #{n}"
      return do_match(glob, name[1..])
    when '{'
      glob, str = get_group(glob[1..], '}')
      #STDERR.puts "brace: new glob '#{glob}', group '#{str}'"
      strs = str.split(',')
      #STDERR.puts "brace: strs #{strs}"
      if strs.size == 1
	if "{#{str}}" == name[0, str.size+2]
	  return do_match(glob, name[str.size+2..])
	end
      end
      strs.each do |s|
	if s == name[0,s.size]
	  #STDERR.puts "brace: matched #{s}"
	  return do_match(glob, name[s.size..])
	end
      end
      return false
    else
      n = name[0]?
      return false unless n
      return false if g != n
      return do_match(glob[1..], name[1..])
    end
    return false
  end      
      
  # Returns true if *filename* is matched by this section's
  # glob pattern.  If the glob has a forward slash, then
  # *filename* must be in a subdirectory of this section's
  # .editorconfig file that exactly matches the glob.  Otherwise,
  # *filename* may be in any subdirectory.
  def match(filename : String) : Bool
    #STDERR.puts "match: filename #{filename}, glob #{@glob}"

    # The file must be in at or below the directory containing
    # this .editorconfig.
    path = Path[filename].expand.to_s
    return false unless path.starts_with?(@dirname)

    if @glob_has_slash
      # Use the fully expanded glob pattern and filename so that
      # therir directory paths must match.
      return do_match(@fullglob, path)
    else
      # Use the unexpanded glob and filename, so that they will match
      # files in any subdirectory.
      filename = Path[filename].basename
      #STDERR.puts "matching glob #{@glob} against basename #{filename}"
      return do_match(@glob, filename)
    end
  end

end

# `ConfigFile` parses and stores all of the sections for a single .editorconfig file.
# It also stores the preamble key/value pairs found in the file.
class ConfigFile

  # The fully qualified path of the .editorconfig file.
  property fullpath : String

  # The key/value pairs for the preamble.
  property preamble : Hash(String, String)

  # The sections in the .editorconfig file.
  property sections : Array(ConfigSection)

  # True if this is a root .editorocnfig file.
  property root : Bool

  # Parses and stores the preamble and sections from a
  # single .editorconfig file.
  def initialize(@fullpath)
    #STDERR.puts "parsing config file #{@fullpath}"
    @root = false
    @preamble = Hash(String, String).new
    @sections = [] of ConfigSection

    section = nil
    File.read_lines(fullpath).each do |line|
      l = line.strip
      next if l.size == 0
      next if l[0] == '#' || l[0] == ';'
      if l =~ /^(.+)=(.+)$/
	key = $1.strip
	value = $2.strip
	if section
	  #STDERR.puts "section key #{key}, value #{value}"
	  section.addpair(key, value)
	else
	  #STDERR.puts "preamble key #{key}, value #{value}"
	  preamble[key.downcase] = value
	end
      elsif l =~ /^\[(.+)\]$/
	name = $1
	#STDERR.puts "New section #{name}"
	section = ConfigSection.new(name, fullpath)
	sections << section
      else
	#STDERR.puts "Unrecognized line '#{l}'"
      end
    end
    if root = preamble["root"]?
      @root = (root.downcase == "true")
    end
  end

end

# `Config` stores information about all of the .editorconfig
# files it finds while traversing up the directory tree.
class Config
  property files : Array(ConfigFile)
  
  # Walks up the directory tree, looking for and parsing any
  # .editorconfig files it finds, until it reaches the root
  # directory or finds a .editorconfig file with "root = true"
  # in the preamble.
  def initialize
    @files = [] of ConfigFile
    fname = ".editorconfig"

    # Use an arbitrary maximum tree ascent count to guard
    # against a failure to stop at the root directory.
    count = 0
    while count < 20
      count += 1
      fullpath = Path[fname].expand
      if File.exists?(fullpath)
	path = fullpath.to_s
	configfile = ConfigFile.new(path)
	@files.unshift(configfile)
	break if configfile.root
      end
      break if File.dirname(fullpath) == "/"
      fname = "../#{fname}"
    end
  end

  # Gets the value named *key* from the closest .editorconfig file
  # whose glob match matches *filename*.  Returns *default* if
  # the value is not found.
  def getvalue(filename : String, key : String, default = "") : String
    value = default
    @files.each do |f|
      f.sections.each do |s|
	if s.match(filename)
	  s.pairs.each do |k, v|
	    if key == k
	      if v == "unset"
		value = default
	      else
		value = v
	      end
	      #STDERR.puts "Found #{key} in #{s.glob}, v was '#{v}', setting value to '#{value}'"
	    end
	  end
	end
      end
    end
    return value
  end
	  
end

{% if flag?(:TEST) %}

if ARGV.size < 1
  puts "usage: filename..."
  exit 1
end

puts "Config files:"
c = Config.new
c.files.each do |f|
  puts "Path #{f.fullpath}, root #{f.root}"
  f.sections.each do |s|
    puts "  Section glob #{s.glob}, dir #{s.dirname}"
    s.pairs.each do |k, v|
      puts "    #{k} = #{v}"
    end
    ARGV.each do |filename|
      if s.match(filename)
	puts "  Section matched #{filename}"
      else
	puts "  Section did not match #{filename}"
      end
    end
  end
end

ARGV.each do |filename|
  value = c.getvalue(filename, "indent_size", "3")
  puts "indent_size for #{filename} = '#{value}'"
  value = c.getvalue(filename, "tab_width", "6")
  puts "tab_width for #{filename} = '#{value}'"
end

{% end %} # flag TEST
