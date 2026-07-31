#!/usr/bin/env ruby

require 'json'

# JSON-RPC error codes

ERROR_METHOD    = -32601	# Method not found
ERROR_EXCEPTION = -32000	# Server error - exception

# Trap SIGINT so we can cleanly cause Ruby to
# exit instead of killing MicroEMACS.

Signal.trap('INT') do
 raise "Received SIGINT signal"
end

# Logging during debugging.

DEBUG = false
$logfile = nil

def dprint(s)
  if DEBUG
    unless $logfile
      $logfile = File.open("server.log", "w")
    end
    $logfile.puts s
    $logfile.flush
  end
end

# MicroEMACS functions return a trinary value.  We have
# to use an "E" prefix to avoid conflicts with Ruby's
# builtin constants.

EFALSE = 0
ETRUE  = 1
EABORT = 2

# The variable E.bflag (the current buffer's flags) is an OR
# of the following values.

BFCHG = 1	# changed
BFBAK = 2	# need backup
BFRO  = 4	# read-only

###
### Key -
### Encapsulate a keystroke in its own type so that
### it can be distinguished from a numeric argument
### to cmd.
###

class Key

  CTRL = 0x10000000
  META = 0x20000000
  CTLX = 0x40000000
  CHARMASK = 0x10ffff
  KRANDOM = 0x80
  F1     = 0x8b
  F2     = 0x8c
  F3     = 0x8d
  F4     = 0x8e
  F5     = 0x8f
  F6     = 0x90
  F7     = 0x91
  F8     = 0x92
  F9     = 0x93
  F10    = 0x94
  F11    = 0x95
  F12    = 0x96

  def initialize(c, f=0)
    if c.is_a?(String)
      if f != 0
	@key = c.upcase.ord | f
      else
	@key = c.ord
      end
    else
      @key = c | f
    end
  end

  def to_i
    @key
  end

  def char
    (@key & CHARMASK).chr('UTF-8')
  end

  def ctrl?
    (@key & CTRL) != 0
  end

  def meta?
    (@key & META) != 0
  end

  def ctlx?
    (@key & CTLX) != 0
  end

  def normal?
    (@key & (CTRL | META | CTLX)) == 0
  end

  def ==(k)
    self.to_i == k.to_i
  end

  def to_s
    s = ""
    if (@key & CTLX) != 0
      s << "C-X "
    end
    if (@key & META) != 0
      s << "M-"
    end
    if (@key & CTRL) != 0
      s << "C-"
    end
    if self.normal?
      s << self.char
    else
      s << self.char.upcase
    end
  end

end

def key(c)
  Key.new(c)
end

def ctrl(c)
  Key.new(c, Key::CTRL)
end

def meta(c)
  Key.new(c, Key::META)
end

def ctlx(c)
  Key.new(c, Key::CTLX)
end

def metactrl(c)
  Key.new(c, Key::META | Key::CTRL)
end

def ctlxctrl(c)
  Key.new(c, Key::CTLX | Key::CTRL)
end

###
### E - singleton class that provides an interface to MicroEMACS.
###

class E
  # The id that we supply with each message we send to the editor.
  # We increment it by 2 with each use, to avoid confusion with
  # ids from the editor, which are odd numbers.
  @@id = 2

  # Hash of name => bool, saying whether that name is
  # is valid MicroEMACS command.
  @@iscmd = {}

private

  # Trap an unknown method call for the E class.  We assume this is
  # a call to a MicroEMACS command.  First, replace underscores with
  # dashes in the method name.  Then query MicroEMACS to
  # see if this is a valid command.  If it is, send a method
  # call to MicroEMACS to run the command.
  def self.method_missing(m, *args, &block)
    #dprint "method_missing #{m}, has .name = #{m.respond_to?(:name)}"
    c = m.to_s.gsub('_','-')
    dprint "m = #{m.to_s}, c = #{c}"
    super(m, *args) unless E.iscmd(c)
    #dprint "Calling cmd #{m}"

    # Marshall the arguments.  Any or none can be specified, but
    # we assume there is only one of each type:
    # - int (numeric prefix),
    # - key object
    # - string
    f = 0
    n = 1
    k = Key::KRANDOM
    s = []
    args.each do |arg|
      #dprint "arg: #{arg} (#{arg.class})"
      case arg
      when Integer
	dprint "int arg = #{arg}"
	f = 1
	n = arg
      when Key
	dprint "key = #{arg.to_s}"
	k = arg.to_i
      when String
	#dprint "string = #{arg}"
	s << arg
      else
	#dprint "unknown arg type: method = #{m}, arg = #{arg}, class = #{arg.class}"
      end
    end
    dprint "method_missing: calling #{c}"
    ret = self.cmd(c, f, n, k, s)
    dprint "method_missing: done calling #{c}"
    return ret
  end

  # Send a hash as RPC message.
  def self.send_message(hash)
    hash["jsonrpc"] = "2.0"	# not actually needed, but insert it for completeness
    json = JSON.generate(hash);
    puts "#{json.bytesize}"
    print json
    STDOUT.flush
    dprint "===\nSent #{json.bytesize} bytes:\n#{json}"
  end

  # Read an RPC message, return it as a hash, or nil
  # if unrecoverable error occurred.
  def self.read_message
    # Read the line containing the size of the JSON payload,
    # then read the JSON.
    str = STDIN.gets
    unless str
      return nil
    end
    nbytes = str.to_i
    if nbytes > 0
      str = STDIN.read(nbytes, str)
    else
      # Empty response.  Maybe the pipe has been closed?
      return nil
    end
    dprint "===\nReceived #{str}"
    return JSON.parse(str)
  end

  # If a JSON response is not provided, read a JSON response.
  # If the ID in the response matches, return the hash
  # representing the JSON.  If the ID doesn't match, or if
  # there's another error, return nil.
  def self.read_response(expected_id, json=nil)
    # Read the JSON string and convert it to a hash.
    unless json
      json = read_message
      return nil unless json
    end

    # Parse the JSON and determine if it indicates success or error.
    if error = json["error"]
      error_message = error["message"]
      dprint "error response #{error_message}!\n"
      return nil
    else
      result = json["result"].to_i
      id = json["id"].to_i
      if id != expected_id
	dprint "response ID was #{id}, expected #{expected_id}"
	return nil
      else
	dprint "Got expected response id #{id}"
	return json
      end
    end
  end

  # Process an incoming command, return true if successful,
  # false if unrecoverable error.
  def self.process_command(json=nil)
    # Read JSON message if it was not passed in.
    unless json
      dprint "process_command: waiting for a message"
      json = read_message
      return false unless json
    end

    # Parse the JSON and extract the parameters.
    method = json["method"]
    unless params = json["params"]
      return false
    end
    flagstr = params["flag"]
    if flagstr
      flag = flagstr.to_i
    else
      flag = 0
    end
    prefixstr = params["prefix"]
    if prefixstr
      prefix = prefixstr.to_i
    else
      prefix = 0
    end
    keystr = params["key"]
    if keystr
      key = keystr.to_i
    else
      key = 0
    end
    id = json["id"].to_i
    strs = params["strings"]
    if strs
      strings = "[" + strs.join(", ") + "]"
    else
      strings = "[]"
      strs = []
    end
    dprint "command: id #{id}, method #{method}, flag #{flag}, prefix #{prefix}, key #{key}, strings #{strings}"

    # If there is a Ruby method that has the name of the commmand, call it
    # and return a normal response.  Otherwise return an error response.
    # The command method can send calls to the editor before it returns,
    # but those calls must not be reentrant, i.e., they must not call
    # back into the server.
    if respond_to?(method,true)
      exc = nil
      begin
        # Command can fetch the optional string array (strs) with yield.
	# We ignore the key parameter for now.  Maybe pass it to yield?
        ret = send(method, flag == 1 ? prefix : nil) { strs }
      rescue => x
        exc = x.message + "\n" + x.backtrace.join("\n")
      end
      if exc
	send_message({id: id, error: {code: ERROR_EXCEPTION, message: "Exception:\n#{exc}"}})
	exc = nil
      else
	dprint "#{method} returned #{ret}"
	if ret.is_a?(Array)
	  result = ret[0]
	  msg = ret[1]
	else
	  result = ret
	  msg = ""
	end
	if result != ETRUE
	  send_message({id: id, error: {code: result, message: msg}})
	else
	  send_message({id: id, result: ETRUE, string: "success: id #{id}, method #{method}, message '#{msg}'"})
	end
      end
    else
      send_message({id: id, error: {code: ERROR_METHOD, message: "Method not found"}})
    end
    dprint "process_command: returning true"
    return true
  end

  # Get a string from the editor.
  # - name: the name of the string
  # - string: additional string parameter (could be nil)
  def self.get_string(name, string)
    send_message({method: "get", params: {name: name, string: string}, id: @@id})
    json = read_response(@@id)
    @@id += 2
    return json.nil? ? "" : json["string"]
  end

  # Get an integer from the editor.
  # - name: the name of the string
  # - string: additional string parameter (could be empty)
  def self.get_int(name, string)
    send_message({method: "get", params: {name: name, string: string}, id: @@id})
    json = read_response(@@id)
    @@id += 2
    return json.nil? ? 0 : json["result"]
  end

  def self.set(name, int, string)
    send_message({method: "set", params: {name: name, int: int, string: string}, id: @@id})
    read_response(@@id)
    @@id += 2
  end

public

  ####
  #### Getters and setters for objects in the editor
  ####

  # Getters can take an additional string parameter,
  # and setters can take an integer and a string parameter.
  # Variables supported: lineno, offset, line, char,
  # filename, tabsize, fillcol, bflag, bname

  def self.char
    return get_string("char", "")
  end

  def self.char=(val)
    set("char", 0, val)
  end

  def self.line
    return get_string("line", "")
  end

  def self.line=(val)
    set("line", 0, val)
  end

  def self.lineno
    return get_int("lineno", "")
  end

  def self.lineno=(val)
    set("lineno", val, "")
  end

  def self.bflag=(val)
    set("bflag", val, "")
  end

  def self.bflag
    return get_int("bflag", "")
  end

  def self.offset=(val)
    set("offset", val, "")
  end

  def self.offset
    return get_int("offset", "")
  end

  def self.filename
    return get_string("filename", "")
  end

  def self.filename=(val)
    set("filename", 0, val)
  end

  def self.popup(s)
    set("popup", 0, s)
  end

  def self.getkey
    return Key.new(get_int("key", ""))
  end

  def self.fillcol
    return get_int("fillcol", "")
  end

  def self.tabsize
    return get_int("tabsize", "")
  end

  ####
  #### Non-command calls into MicroEMACS.
  ####

  def self.bind(name, key, mode=false)
    # This is hack: prefix the name with a "T" or "F", indicating
    # the value of mode.
    set("bind", key.to_i, (mode ? "T" : "F") + name.gsub('_','-'))
  end

  def self.reply(s)
    get_string("reply", s)
  end

  def self.insert(s)
    set("insert", 0, s);
  end

  def self.setmode(s)
    set("mode", 0, s)
  end

  def self.update
    set("update", 0, "")
  end

  ###
  ### Methods for running commands built into MicroEMACS.
  ###

  # Does the specified command exist in MicroEMACS?
  def self.iscmd(cmd)
    # Check the hash table first.  If nothing there,
    # send a message asking if this is a real command.
    result = @@iscmd[cmd]
    if result
      dprint "iscmd: got result #{result} from hash"
    else
      result = get_int("iscmd", cmd)
      @@iscmd[cmd] = result
      dprint "iscmd: stored result #{result} in hash"
    end
    return result == 1
  end

  # Run a MicroEMACS command, return true if successful.
  def self.cmd(name, flag, prefix, key, s)
    return unless self.iscmd(name)
    id = @@id
    send_message({method: "cmd",
	params: {name: name,
		 flag: flag,
		 prefix: prefix,
		 key: key,
		 strings: s}, id: id})

    # Keeping reading messages.  If we get method call message,
    # process that.  Exit the loop when we see the expected response message.
    done = false
    until done
      json = read_message
      if json
	if json["method"]
	  process_command(json)
	else
	  json = read_response(id, json)
	  if json
	    done = true
	  end
	end
      else
	done = true
      end
    end
    dprint "self.cmd: response = #{json}"
    @@id += 2
    return json.nil? ? EFALSE : json["result"]
  end

  # Helper function that fetches the optional string parameter for a command.
  # Commands that use getstr must declare the block as a second parameter
  # named &b, then pass &b to getstr.
  def self.getstr
    if block_given?
      strs = yield
      if strs.length > 0
	return strs[0]
      end
    end
    return nil
  end

  # Main server loop.  Should run forever unless a fatal error occurs.
  def self.server_loop
    while process_command
    end
  end
end

# Non-command functions needed by MicroEMACS.

def exec(n, &b)
  cmd = E.getstr(&b)
  if cmd
    eval(cmd)
    return [ETRUE, "exec ran '#{cmd}'"]
  else
    return [EFALSE, "exec called without a string"]
  end
end

def loadfile(n, &b)
  filename = E.getstr(&b)
  if filename
    load(filename)
    return [ETRUE, "loadfile loaded #{filename}"]
  else
    return [EFALSE, "loadfile called without a string"]
  end
end

# A mode is a record containing a name and a set of key bindings;
# this record is attached to a particular buffer.  Key bindings
# in a mode override those in the global key binding table.
#
# MicroEMACS calls initmode whenever a new buffer is opened.
# It uses the following two stratagies to determine the name
# of the mode for the buffer:
#
#   1. Look at the first non-blank line, and if it contains
#      the string -*-MODE-*-, MODE specifies the mode name
#   2. If strategy #1 fails, look at the filename, and see if
#      it matches any of the patterns in the $modetable below
#
# If a mode name is determined, run the function MODE_mode,
# if present, where MODE is the mode name.  The user must provide
# one or more of these functions to implement the desired modes.
#
# A mode function will typically perform any necessary buffer
# manipulation, then define one or more MicroEMACS functions,
# and finally bind some keys to that mode.  See dired.rb
# for an example.

# Table associating filename patterns to mode names.
$modetable = [
  [ /\.c$/,   "c" ],
  [ /\.rb$/,  "ruby" ],
  [ /\.cc$/,  "cplusplus" ],
  [ /\.cpp$/, "cplusplus" ],
  [ /\.cr$/,  "crystal" ],
  [ /\.sh$/,  "shell" ]
]

# This function is called whenever a file is read into a buffer.
# It attempts to determine the mode for the file, and then
# call the function associated with that mode.

def initmode(n)
  mode = nil
  f = E.filename

  # Try to determine the mode from the first non-blank line
  # in the file, which could contain a mode specification like this:
  #   -*-Mode-*-
  # The mode is lower-cased before checking for the hook function,
  lineno = E.lineno
  #linelen = E.line.length
  offset = E.offset
  E.goto_bob
  keepgoing = true
  while keepgoing
    l = E.line.chomp
    if l =~ /^\s*$/	# skip leading blank lines
      keepgoing = E.forw_line == ETRUE
    else
      keepgoing = false
      if l =~ /-\*-(\w+)-\*-/
	mode = $1.downcase
      end
    end
  end
  E.lineno = lineno
  E.offset = offset

  # Try to determine the mode from the filename pattern.
  if mode.nil?
    match = $modetable.find {|a| f =~ a[0] }
    if match
      mode = match[1]
    end
  end

  # If a mode hook function exists, call it
  if mode.nil?
    return [ETRUE, "unable to determine mode"]
  end
  hook = mode + "_mode"
  if Object.respond_to?(hook, true)
    Object.send hook
    return [ETRUE, "called mode hook #{hook}"]
  else
    return [ETRUE, "unknown mode hook #{hook}"]
  end
end

# Set the default encoding for strings.
Encoding.default_internal = 'UTF-8'

E.server_loop
