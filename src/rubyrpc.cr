require "json"

# The `RubyRPC` module contains methods for implementing Ruby
# extensions in the editor in a manner identical to that used
# in MicroEMACS.  It communicates with the Ruby
# server `/usr/local/share/pe/server.rb` via JSON, specifically
# the JSON-RPC protocol defined in <https://www.jsonrpc.org/specification>.
# Further information about Ruby extensions can be found
# in the MicroEMACS documentation.
module RubyRPC
  @@tried = false
  @@process : Process | Nil
  @@id = 1

  # JSON-RPC error codes
  ERROR_METHOD    = -32601	# Method not found
  ERROR_PARAMS    = -32602	# Invalid params
  ERROR_EXCEPTION = -32000	# Server error - exception

  # Server filename.
  SERVER_FILENAME = "/usr/local/share/pe/server.rb"

  # Ruby extension in current directory.
  EXTENSION_FILENAME = "./.pe.rb"

  extend self

  # Loads the Ruby server (`server.rb`), and if that is successful,
  # loads the Ruby file `.pe.rb`, which contains the directory-local
  # Ruby extensions.  Returns true if the server initialized successfully,
  # or false otherwise.
  def load_server : Bool
    # Don't need to do anything if we've already loaded the server.
    if @@process
      return true
    end

    # If we've already tried to load the server, it must have failed,
    # so don't try again.
    if @@tried
      return false
    end
    @@tried = true
    @@id = 1

    # Load the Ruby server.
    prog = SERVER_FILENAME
    begin
      @@process = Process.new(prog,
			     nil,
                             input: Process::Redirect::Pipe,
                             output: Process::Redirect::Pipe,
                             error: Process::Redirect::Pipe,
			     shell: false)
      E.log("Created process for #{prog}")
    rescue IO::Error
      msg = "Unable to load #{prog}"
      E.log(msg)
      Echo.puts(msg)
      @@process = nil
      return false
    end

    # Load the local Ruby extension code.
    if File.exists?(EXTENSION_FILENAME)
      loadscript(EXTENSION_FILENAME)
    end
    return true
  end

  # Initializes the Ruby server if there is a Ruby extension
  # named `.pe.rb` in the current directory.  Returns true
  # if .pe.rb doesn't exist, or if the server was loaded successfully.
  def init_server : Bool
    if File.exists?(EXTENSION_FILENAME)
      return load_server
    else
      return true
    end
  end

  # Returns the server's input file, or nil if the server
  # can't be loaded.
  def input_file : IO?
    return nil if !load_server
    f = nil
    if p = @@process
      f = p.input?
    end
    return f
  end

  # Returns the server's output file, or nil if the server
  # can't be loaded.
  def output_file : IO?
    return nil if !load_server
    f = nil
    if p = @@process
      f = p.output?
    end
    return f
  end

  # Sends a JSON message to the server in two pieces:
  # * a line containing the size of the JSON payload in decimal
  # * the JSON payload itself
  def send_message(json : String)
    f = input_file
    unless f
      E.log("No server process, can't send RPC message")
      return
    end
    f.puts(json.bytesize)
    f.print(json)
    E.log("====\nSent #{json}")
  end
    
  # Constructs a JSON string for a call to a Ruby command to be sent to the server.
  # * *method*: name of command
  # * *flag*: 1 if command was preceded by a C-u numeric prefix
  # * *prefix*: numeric prefix (undefined if flag is 0)
  # * *key*: editor internal keycode that invoked the command
  # * *strings*: array of strings to pass to the command
  # * *id*: unique request ID
  #
  # Example JSON:
  # ```
  #   {"jsonrpc": "2.0",
  #     "method": "stuff",
  #      "params": {"flag": 1, "prefix": 42, "key": 9, "strings": ["a string"]  }, "id": 1}
  # ```
  def make_rpc_request(method : String, flag : Int32, prefix : Int32, key,
		       strings : Array(String), id : Int32) : String
    string = JSON.build do |json|
      json.object do
	json.field "jsonrpc", "2.0"
	json.field "id", id
	json.field "method", method
	json.field "params" do
	  json.object do
	    json.field "flag", flag
	    json.field "prefix", prefix
	    json.field "key", 9
	    json.field "strings" do
	      json.array do
		strings.each do |s|
		  json.string s
		end
	      end
	    end
	  end
	end
      end
    end
    return string
  end

  # Constructs a JSON string for an error response to be sent to the server.
  # * *code*: error code
  # * *message*: error message
  # * *id*: unique request ID
  #
  # Example JSON:
  # ```
  #   {"id":4,"error":{"code":-32602,"message":"Invalid parameter"}}
  # ```
  def make_error_response(code : Int32, message : String, id : Int32) : String
    string = JSON.build do |json|
      json.object do
	json.field "jsonrpc", "2.0"
	json.field "id", id
	json.field "error" do
	  json.object do
	    json.field "code", code
	    json.field "message", message
	  end
	end
      end
    end
  end

  # Constructs a JSON string for a non-error response to be sent to the server.
  # * *result*: result code
  # * *string*: additional optional string result
  # * *id*: unique request ID
  #
  # Example JSON:
  # ```
  #   {"id":4,"result":0,"string":"success: id 4, method callback"}
  # ```
  def make_normal_response(result : Int32, string : String | Nil, id : Int32) : String
    string = JSON.build do |json|
      json.object do
	json.field "jsonrpc", "2.0"
	json.field "id", id
	json.field "result", result
	json.field "string", string
      end
    end
  end

  # Gets a string member *name* from the JSON object *obj*, or returns nil
  # if the member is not found.
  def get_string(obj : JSON::Any, name : String) : String | Nil
    s = obj[name]?
    if s
      return s.as_s
    else
      return nil
    end
  end

  # Gets an integer member *name* from the JSON object *obj*, or returns 0
  # if the member is not found.
  def get_int(obj : JSON::Any, name : String) : Int32
    id = obj[name]?
    if id
      return id.as_i
    else
      return 0
    end
  end

  # Returns true if the JSON object *obj* is a method call message.
  def is_call(obj : JSON::Any)
    return !obj["method"]?.nil?
  end

  # Returns true if the JSON object *obj* is a result message.
  def is_result(obj : JSON::Any)
    return !obj["result"]?.nil?
  end

  # Returns true if the JSON object *obj* is an error message.
  def is_error(obj : JSON::Any)
    return !obj["error"]?.nil?
  end

  # Processes a request from the server to run an editor command.
  # Returns true if we should keep reading messages from the
  # server, or returns false if there's an error and we
  # should stop reading messages from the server.
  # * *id*: the ID associated with the request
  # * *params*: the params JSON object from request
  def handle_cmd(id : Int32, params : JSON::Any) : Bool
    name = get_string(params, "name")
    flag = get_int(params, "flag")
    prefix = get_int(params, "prefix")
    key = get_int(params, "key")

    # Put each string in the strings array into the reply queue.
    strings = params["strings"]?
    if strings
      E.log("handle_cmd: strings:")
      a = strings.as_a
      a.each do |s|
        str = s.as_s
	E.log("  #{str}")
	Echo.replyq_put(str)
      end
    end

    # Call the editor command `name`.  If the buffer has a mode,
    # try using its keymap first, then try the global keymap
    if name.nil?
      E.log("Missing command name")
      return false
    end
    b = E.curb
    if b.modename.size != 0 && b.keymap.name_bound?(name)
      keymap = b.keymap
    else
      keymap = E.keymap
    end
    result = keymap.call_by_name(name, flag != 0, prefix, key)

    # Send a response, unless it's a notification that expects no response,
    # as indicated by an id of 0 (i.e., the id was missing in the request).
    message = "handle_cmd: ran #{name}, result #{result}"
    E.log(message)
    response = make_normal_response(result.to_i, message, id)
    send_message(response)
    return true	# keep reading messages from the server
  end

  # These functions handle requests from the Ruby server to perform
  # "get" operations on virtual variables in the editor.  Some of these
  # operations do more that getting a variable, e.g., testing
  # that a particular editor command exists.

  def get_line(id : Int32) : String
    w, b, dot, lp = E.get_context
    # Append a newline if this is not the last line.
    return make_normal_response(0, lp.text + (lp == b.last_line ? "" : "\n"), id)
  end

  def get_lineno(id : Int32) : String
    w, b, dot, lp = E.get_context
    return make_normal_response(dot.l + 1, "", id)
  end

  def get_iscmd(id : Int32, str : String | Nil) : String
    if str.nil?
      message = "Missing command name for get_iscmd"
      E.log(message)
      return make_error_response(ERROR_PARAMS, message, id)
    end

    # If the buffer has a mode, check its keymap first;
    # then check the global keymap.
    b = E.curb
    if b.modename.size != 0 && b.keymap.name_bound?(str)
      found = true
    else
      found = E.keymap.name_bound?(str)
    end
    return make_normal_response(found ? 1 : 0, found ? "found" : "not found", id)
  end

  def get_reply(id : Int32, prompt : String | Nil) : String
    if prompt.nil?
      message = "Missing prompt for get_reply"
      E.log(message)
      return make_error_response(ERROR_PARAMS, message, id)
    end
    result, str = Echo.reply(prompt, nil)
    if result == ABORT
      return make_normal_response(0, nil, id)
    else
      return make_normal_response(0, str, id)
    end
  end

  def get_bflag(id : Int32) : String
    return make_normal_response(E.curb.flags.to_i, "", id)
  end

  def get_offset(id : Int32) : String
    return make_normal_response(E.curw.dot.o, "", id)
  end

  def get_filename(id : Int32) : String
    return make_normal_response(0, E.curb.filename, id)
  end

  def get_key(id : Int32) : String
    key = E.kbd.getkey
    return make_normal_response(key, "", id)
  end

  # Handles a request from the Ruby server get a virtual variable from the editor.
  # The variables can be real ones, like the current line or line number.
  # They can also be pseudo-variables that perform actions, like prompting
  # the user to enter a reply, or waiting for a keystroke.
  # * *id*: the ID associated with the request
  # * *params*: the params JSON object from request
  def handle_get(id : Int32, params : JSON::Any) : Bool
    name = get_string(params, "name")
    if name.nil?
      E.log("Missing get name")
      return false
    end
    E.log("handle_get: name #{name}")
    string = get_string(params, "string")

    response = case name
    when "line"     then get_line(id)
    when "lineno"   then get_lineno(id)
    when "iscmd"    then get_iscmd(id, string)
    when "reply"    then get_reply(id, string)
    when "bflag"    then get_bflag(id)
    when "offset"   then get_offset(id)
    when "filename" then get_filename(id)
    when "key"      then get_key(id)
    else
      make_error_response(ERROR_PARAMS, "no such variable {name}", id)
    end
    send_message(response)

    return true
  end

  # These functions handle requests from the Ruby server to perform
  # "set" operations on virtual variables in the editor.  Some of these
  # operations do more that setting a variable, e.g., inserting a
  # string

  def set_line(int id, str : String | Nil) : String
    w, b, dot, lp = E.get_context
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing line for set_line", id)
    end
    dot.o = 0
    Line.delete(lp.text.size, false)
    Line.insert(str)
    return make_normal_response(0, "", id)
  end

  def set_lineno(id : Int32, lineno : Int32) : String
    lineno -= 1		# Internally we use zero-based line numbers
    if lineno >= 0 && lineno < E.curb.size
      E.curw.dot = Pos.new(lineno, 0)
    end
    return make_normal_response(0, "", id)
  end

  def set_bind(id : Int32, key : Int32, str : String | Nil) : String
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing command name for set_bind", id)
    end
    mode = str[0]
    name = str[1..]

    # If this buffer has a mode, use its keymap;
    # otherwise use the global keymap.
    b = E.curb
    if b.modename.size == 0
      E.log("set_bind: using global keymap instead of buffer #{b.name} for key #{key.to_s(16)}")
      k = E.keymap
    else
      E.log("set_bind: using buffer #{b.name} keymap for key #{key.to_s(16)}")
      k = b.keymap
    end

    if !k.name_bound?(name)
      E.log("set_bind: name #{name} is not bound")
      message = "No such command #{name}"
      Echo.puts(message)
      return make_error_response(ERROR_METHOD, message, id)
    end
    E.log("set_bind: binding #{key} to #{name}")
    k.add_dup(key, name)
    return make_normal_response(0, "", id)
  end

  def set_bflag(id : Int32, int : Int32) : String
    E.curb.flags = Bflags.new(int)
    return make_normal_response(0, "", id)
  end

  def set_insert(id : Int32, str : String | Nil) : String
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing string for set_insert", id)
    end
    Line.insertwithnl(str)
    return make_normal_response(0, "", id)
  end

  def set_offset(id : Int32, offset : Int32) : String
    w, b, dot, lp = E.get_context
    if offset > lp.text.size
      Echo.puts("Offset #{offset} too large")
    else
      dot.o = offset
    end
    return make_normal_response(0, "", id)
  end

  def set_mode(int id, str : String | Nil) : String
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing mode for set_mode", id)
    end
    if str.size == 0
      Echo.puts("Blank mode name")
    else
      E.curb.modename = str
    end
    E.log("Setting buffer #{E.curb.name} modename to #{str}")
    return make_normal_response(0, "", id)
  end

  def set_filename(int id, str : String | Nil) : String
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing filename for set_filename", id)
    end
    E.curb.filename = str
    return make_normal_response(0, "", id)
  end

  def set_popup(int id, str : String | Nil) : String
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing string for set_popup", id)
    end

    # Clear the system buffer, then fill it with the lines in `str`.
    b = Buffer.sysbuf
    b.clear
    str.lines.each {|s| b.addline(s)}

    # Display the system buffer.
    Buffer.popsysbuf

    return make_normal_response(0, "", id)
  end

  # Handles a request from the Ruby server to set a virtual variable
  # in the editor. These can be real variables
  # like the current line number or the current line.  They can
  # also be pseudo-variables that perform actions, like inserting text
  # or popping up an error window.
  # * *id*: the ID associated with the request
  # * *params*: the params JSON object from request
  def handle_set(id : Int32, params : JSON::Any) : Bool
    name = get_string(params, "name")
    string = get_string(params, "string")
    int = get_int(params, "int")
    if name.nil?
      E.log("Missing set name")
      return false
    end
    response = case name
    when "line"     then set_line(id, string)
    when "lineno"   then set_lineno(id, int)
    when "bind"     then set_bind(id, int, string)
    when "bflag"    then set_bflag(id, int)
    when "insert"   then set_insert(id, string)
    when "offset"   then set_offset(id, int)
    when "mode"     then set_mode(id, string)
    when "filename" then set_filename(id, string)
    when "popup"    then set_popup(id, string)
    else
      make_error_response(ERROR_PARAMS, "no such variable {name}", id)
    end
    send_message(response)
    return true
  end

  # Handles a JSON method call object *obj* from the Ruby server.
  # There are three types of method calls we can receive:
  # * cmd - run an editor command
  # * set - set an editor virtual variable
  # * get - get an editor virtual variable
  def handle_call(obj : JSON::Any) : Bool
    method = get_string(obj, "method")
    unless method
      E.log("Unable to get method from JSON")
      return false
    else
      E.log("handle_call: method #{method}")
    end
    id = get_int(obj, "id")
    E.log("handle_call: id #{id}")

    # There should always be a params object.
    params = obj["params"]?
    if params.nil?
      E.log("Unable to get params from JSON")
      return false
    end

    # Handle the three different call types.
    case method
    when "cmd"
      return handle_cmd(id, params)
    when "set"
      return handle_set(id, params)
    when "get"
      return handle_get(id, params)
    else
      response = make_normal_response(1, "Method #{method} not found", id)
      send_message(response)
      return false
    end
    return true
  end

  # Parses a JSON error object *obj* from the server. Returns false to tell the caller
  # that we can stop reading messages, or true to continue reading messages.
  def handle_error(obj : JSON::Any) : Bool
    id = obj["id"]?
    if id
      E.log("id: #{id.as_i}")
    end
    params = obj["error"]?
    if params
      h = params.as_h
      code = h["code"].as_i?
      E.log("code: #{code}") if code
      message = h["message"].as_s?
      E.log("message: #{message}") if message
      if code == ERROR_EXCEPTION
	set_popup(0, message)
      end
    else
      E.log("Unable to get error from JSON")
      return false
    end
    return false
  end

  # Parses a JSON result object *obj* from the server, whose ID is expected
  # to be *expected_id*.  Returns a tuple containing:
  # * a flag saying whether we should keep reading messages
  # * a result code extracted from the JSON
  #
  # The flag is true if we didn't see the expected result message (i.e, the
  # the ID didn't match the method call we just made), meaning we
  # should keep reading messages.
  #
  # The flag is false if we did see the expected result message, meaning
  # we can stop reading messages.
  def handle_result(obj : JSON::Any, expected_id : Int32) : Tuple(Bool, Result)
    id = get_int(obj, "id")
    result_code = get_int(obj, "result")
    string = get_string(obj, "string") || "<none>"
    E.log("handle_result: id #{id}, expected_id #{expected_id}, result #{result_code}, string #{string}")
    return {id != expected_id, Result.new(result_code)}
  end

  # Reads the JSON payload in two pieces:
  # * a line containing the size of the JSON payload in decimal
  # * the JSON payload itself
  #
  # Returns the JSON object representing it, or nil if there's an error.
  def read_rpc_message : JSON::Any | Nil
    # Read the line containing the size of the JSON in bytes.
    f = output_file
    unless f
      E.log("No server process, can't read RPC message")
      return nil
    end
    s = f.gets
    if s.nil?
      E.log("Unable to read line from server")
      return nil
    end
    E.log("====\nReceived size line:\n#{s}")
    len = s.to_i
    E.log("got len #{len}")

    # Read the JSON payload.
    slice = Bytes.new(len)
    f.read(slice)
    jsonbuf = String.new(slice)
    E.log("got json '#{jsonbuf}'")
    return JSON.parse(jsonbuf)
  end

  # Asks the Ruby server to run a method, and returns the result code
  # it sends back.
  # * *method*: the name of the Ruby method to call
  # * *flag*, *prefix*, *key*: normal parameters for an editor command
  # * *strings*: an array of strings to be passed to non-command Ruby methods.
  def call_server(method : String, flag : Bool, prefix : Int32,
		  key : Int32, strings : Array(String)) : Result
    # Send the message, and bump the ID for the next message.
    id = @@id
    @@id += 2
    msg = make_rpc_request(method, flag ? 1 : 0, prefix, key, strings, id)
    send_message(msg)
    result = TRUE

    # Loop reading responses from the server.  There maybe one or more
    # method calls from the server before it sends a response for
    # the method call we just sent it.
    keep_going = true
    while keep_going
      E.log("call_server: waiting for a message")
      msg = read_rpc_message
      if msg.nil?
        E.log("Couldn't read RPC message")
	break
      end

      # It can be one of three types of messages:
      # - normal response
      # - error response
      # - method call
      if is_result(msg)
	keep_going, result = handle_result(msg, id)
      elsif is_error(msg)
	keep_going = handle_error(msg)
      elsif is_call(msg)
	keep_going = handle_call(msg)
      else
	E.log("Unrecognized message")
      end
    end

    E.log("call_server: returning #{result} from method #{method}")
    return result
  end

  # Runs the Ruby command *name*, passing in the usual command
  # parameters *f*, *n*, and *k*, and returns its result.
  # This is just the scaffold for a future working implementation.
  def rubycall(name : String, f : Bool, n : Int32, k : Int32) : Result
    return FALSE if !load_server
    E.log("rubycall: calling #{name}")
    return call_server(name, f, n, k, [""])
  end

  # Evaluates the Ruby code string *line*, returns the result.
  def runruby(line : String) : Result
    return FALSE if !load_server
    return call_server("exec", true, 1, Kbd::RANDOM, [line])
  end

  # Loads a Ruby script file.
  def loadscript(filename : String) : Result
    return FALSE if !load_server
    if File.exists?(filename)
      return runruby("load '#{filename}'")
    end
    return FALSE
  end
 
  # Commands

  # Prompts for a string, and evaluate the string using the
  # Ruby interpreter.  Return TRUE if the string was evaluated
  # successfully, and FALSE if an exception occurred.
  def rubystring(f : Bool, n : Int32, k : Int32) : Result
    result, string = Echo.reply("Ruby code: ", nil)
    return result if result != TRUE
    return runruby(string)
  end

  # Defines a new editor command that invokes a Ruby function.
  # The Ruby function *name* takes a single parameter, which
  # is the numeric argument to the command, or nil
  # if there is no argument.
  def rubycommand(f : Bool, n : Int32, key : Int32) : Result
    result, name = Echo.reply("Ruby function: ", nil)
    return result if result != TRUE

    # If this buffer has a mode, use its keymap;
    # otherwise use the global keymap.
    b = E.curb
    if b.modename.size == 0
      E.log("rubycommand: using global keymap instead of buffer #{b.name}")
      k = E.keymap
    else
      E.log("rubycommand: using buffer #{b.name} keymap")
      k = b.keymap
    end
    if k.name_bound?(name)
      Echo.puts("#{name} is already defined")
      return FALSE
    end

    # Bind the command to an unused key.  Eventually
    # the Ruby extension will call E.bind to bind
    # the method to a key.
    E.log("rubycommand: binding #{key} to #{name}")
    k.add(Kbd::RANDOM,
	  ->(f : Bool, n : Int32, k : Int32) {
             rubycall(name, f, n, key) },
	  name)
    return TRUE
  end

  # Creates key bindings for all RubyRPC commands.
  def bind_keys(k : KeyMap)
    k.add(Kbd::F6, cmdptr(rubystring), "ruby-string")
    k.add(Kbd::RANDOM, cmdptr(rubycommand), "ruby-command")

    # Test of Ruby binding.  rubycall is not fully implemented yet, 
    # so these only display information on the echo line.
    #k.addruby(Kbd.ctlx('d'), "insdate")
    #k.addruby(Kbd.ctlx('x'), "xact")
  end

end
