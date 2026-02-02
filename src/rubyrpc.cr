require "json"

module RubyRPC
  @@process : Process | Nil
  @@debug = true
  @@id = 1

  # JSON-RPC error codes
  ERROR_METHOD    = -32601	# Method not found
  ERROR_PARAMS    = -32602	# Invalid params
  ERROR_EXCEPTION = -32000	# Server error - exception

  extend self

  def dprint(s : String)
    STDERR.puts(s) if @@debug
  end

  def init_server : Bool
    @@id = 1
    prog = "/usr/local/share/pe/server.rb"
    begin
      @@process = Process.new(prog,
			     nil,
                             input: Process::Redirect::Pipe,
                             output: Process::Redirect::Pipe,
                             error: Process::Redirect::Pipe,
			     shell: false)
      dprint("Created process for #{prog}")
      return true
    rescue IO::Error
      dprint("Unable to create process for #{prog}")
      @@process = nil
      return false
    end
  end

  # Send a JSON message to the server in two pieces:
  # * a line containing the size of the JSON payload in decimal
  # * the JSON payload itself
  def send_message(json : String)
    f = nil
    if p = @@process
      f = p.input?
    end
    unless f
      dprint("No server process, can't send RPC message")
      return nil
    end
    nbytes = json.bytesize
    f.puts(nbytes.to_s)
    f.print(json)
    dprint("====\nSent #{json}")
  end
    
  # make_rpc_request - make a JSON request for a call to a Ruby command
  #
  # * *method*: name of command
  # * *flag*: 1 if command was preceded by a C-u numeric prefix
  # * *prefix*: numeric prefix (undefined if flag is 0)
  # * *key*: editor internal keycode that invoked the command
  # * *strings*: array of strings to pass to the command
  # * *id*: unique request ID
  #
  # Example JSON:
  #   {"jsonrpc": "2.0",
  #     "method": "stuff",
  #      "params": {"flag": 1, "prefix": 42, "key": 9, "strings": ["a string"]  }, "id": 1}
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

  # make_error_response - make a JSON object for an error response.
  #
  # * *code*: error code
  # * *message*: error message
  # * *id*: unique request ID
  #
  # Example JSON:
  #   {"id":4,"error":{"code":-32602,"message":"Invalid parameter"}}
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

  # make_normal_response - make a JSON object for a non-error response.
  #
  # result: result code
  # string: additional optional string result
  # id: unique request ID
  #
  # Example JSON:
  #   {"id":4,"result":0,"string":"success: id 4, method callback"}
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

  # Get a string member from a JSON object, or returns nil
  # if the member is not found.
  def get_string(obj : JSON::Any, name : String) : String | Nil
    s = obj[name]?
    if s
      return s.as_s
    else
      return nil
    end
  end

  # Get an integer member from a JSON object, or returns 0
  # if the member is not found.
  def get_int(obj : JSON::Any, name : String) : Int32
    id = obj[name]?
    if id
      return id.as_i
    else
      return 0
    end
  end

  # Returns true if the JSON object is a method call message.
  def is_call(obj : JSON::Any)
    return !obj["method"]?.nil?
  end

  # Returns true if the JSON object is a result message.
  def is_result(obj : JSON::Any)
    return !obj["result"]?.nil?
  end

  # Returns true if the JSON object is an error message.
  def is_error(obj : JSON::Any)
    return !obj["error"]?.nil?
  end

  # Processes a request to run a MicroEMACS command.
  # Returns true if we should keep reading messages from the
  # server, or returns false if there's an error and we
  # should stop reading messages from the server.
  def handle_cmd(id : Int32, params : JSON::Any) : Bool
    name = get_string(params, "name")
    flag = get_int(params, "flag")
    prefix = get_int(params, "prefix")
    key = get_int(params, "key")

    # Put each string in the strings array into the reply queue.
    strings = params["strings"]?
    if strings
      dprint("handle_cmd: strings:")
      a = strings.as_a
      a.each do |s|
        str = s.as_s
	dprint("  #{str}")
	Echo.replyq_put(str)
      end
    end

    # Call the MicroEMACS command `name`.  If the buffer has a mode,
    # try using its keymap first, then try the global keymap
    if name.nil?
      dprint("Missing command name")
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
    dprint(message)
    response = make_normal_response(result.to_i, message, id)
    send_message(response)
    return true	# keep reading messages from the server
  end

  # These functions handle requests from the Ruby server to perform
  # "get" operations on virtual variables in MicroEMACS.  Some of these
  # operations do more that getting a variable, e.g., testing
  # that a particular MicroEMACS command exists.

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
      dprint(message)
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
      dprint(message)
      return make_error_response(ERROR_PARAMS, message, id)
    end
    result, str = Echo.reply(prompt, nil)
    if result == Result::Abort
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

  # The Ruby server uses a "get" message to ask MicroEMACS to return
  # some internal values.
  def handle_get(id : Int32, params : JSON::Any) : Bool
    name = get_string(params, "name")
    if name.nil?
      dprint("Missing get name")
      return false
    end
    dprint("handle_get: name #{name}")
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
  # "set" operations on virtual variables in MicroEMACS.  Some of these
  # operations do more that setting a variable, e.g., inserting a
  # string

  def set_line(int id, str : String | Nil) : String
    w, b, dot, lp = E.get_context
    if str.nil?
      return make_error_response(ERROR_PARAMS, "missing line for set_line", id)
    end
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
      dprint("set_bind: using global keymap instead of buffer #{b.name} for key #{key.to_s(16)}")
      k = E.keymap
    else
      dprint("set_bind: using buffer #{b.name} keymap for key #{key.to_s(16)}")
      k = b.keymap
    end

    if !k.name_bound?(name)
      dprint("set_bind: name #{name} is not bound")
      message = "No such command #{name}"
      Echo.puts(message)
      return make_error_response(ERROR_METHOD, message, id)
    end
    dprint("set_bind: binding #{key} to #{name}")
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
    dprint("Setting buffer #{E.curb.name} modename to #{str}")
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

  # handle_set - handle a set command
  #
  # The Ruby server uses a "set" message to ask MicroEMACS to perform
  # tasks that are not commands.  These can set variables
  # like the current line number or the current line, but
  # can also perform other actions, like prompting the
  # user for a replay, or inserting text.
  def handle_set(id : Int32, params : JSON::Any) : Bool
    name = get_string(params, "name")
    string = get_string(params, "string")
    int = get_int(params, "int")
    if name.nil?
      dprint("Missing set name")
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

  # Handles an RPC method call from the Ruby server.
  # There are three types of method calls we can receive:
  # * cmd - run a MicroEMACS command
  # * set - set a MicroEMACS virtual variable
  # * get - get a MicroEMACS virtual variable
  def handle_call(obj : JSON::Any) : Bool
    method = get_string(obj, "method")
    unless method
      dprint("Unable to get method from JSON")
      return false
    else
      dprint("handle_call: method #{method}")
    end
    id = get_int(obj, "id")
    dprint("handle_call: id #{id}")

    # There should always be a params object.
    params = obj["params"]?
    if params.nil?
      dprint("Unable to get params from JSON")
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

  # handle_error - parse an error object
  #
  # Parse an error object from the server.
  #
  # Return false to tell the caller that we can stop reading messages.
  def handle_error(obj : JSON::Any) : Bool
    id = obj["id"]?
    if id
      dprint("id: #{id.as_i}")
    end
    params = obj["error"]?
    if params
      h = params.as_h
      code = h["code"].as_i?
      dprint("code: #{code}") if code
      message = h["message"].as_s?
      dprint("message: #{message}") if message
      if code == ERROR_EXCEPTION
	set_popup(0, message)
      end
    else
      dprint("Unable to get error from JSON")
      return false
    end
    return false
  end

  # handle_result - parse a result object
  #
  # Parse a result object from the server, and store the result
  # code to *resultp*.
  #
  # Returns a tuple containing:
  # * flag saying whether we should keep reading messages
  # * result code
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
    dprint("handle_result: id #{id}, expected_id #{expected_id}, result #{result_code}, string #{string}")
    return {id != expected_id, Result.new(result_code)}
  end

  # Reads the JSON payload in two pieces:
  # * a line containing the size of the JSON payload in decimal
  # * the JSON payload itself
  # Return the JSON object representing it, or NULL if there's an error.
  def read_rpc_message : JSON::Any | Nil
    # Read the line containing the size of the JSON in bytes.
    f = nil
    if p = @@process
      f = p.output?
    end
    unless f
      dprint("No server process, can't read RPC message")
      return nil
    end
    s = f.gets
    if s.nil?
      dprint("Unable to read line from server")
      return nil
    end
    dprint("====\nReceived size line:\n#{s}")
    len = s.to_i
    dprint("got len #{len}")

    # Read the JSON payload.
    slice = Bytes.new(len)
    f.read(slice)
    jsonbuf = String.new(slice)
    dprint("got json '#{jsonbuf}'")
    return JSON.parse(jsonbuf)
  end

  # Asks the Ruby server to run a method, which must have the signature
  # of a MicroEMACS command as written in Ruby. Returns the result code
  # it sends back.
  def call_server(method : String, flag : Bool, prefix : Int32,
		  key : Int32, strings : Array(String)) : Result
    # Send the message, and bump the ID for the next message.
    id = @@id
    @@id += 2
    msg = make_rpc_request(method, flag ? 1 : 0, prefix, key, strings, id)
    send_message(msg)
    result = Result::True

    # Loop reading responses from the server.  There maybe one or more
    # method calls from the server before it sends a response for
    # the method call we just sent it.
    keep_going = true
    while keep_going
      dprint("call_server: waiting for a message")
      msg = read_rpc_message
      if msg.nil?
        dprint("Couldn't read RPC message")
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
	dprint("Unrecognized message")
      end
    end

    dprint("call_server: returning #{result} from method #{method}")
    return result
  end

  # Runs the Ruby command *name*, passing in the usual command
  # parameters *f*, *n*, and *k*, and returning its result.
  # This is just the scaffold for a future working implementation.
  def rubycall(name : String, f : Bool, n : Int32, k : Int32) : Result
    dprint("rubycall: calling #{name}")
    return call_server(name, f, n, k, [""])
  end

  # Evaluates a line of Ruby code
  def runruby(line : String) : Result
    return call_server("exec", true, 1, Kbd::RANDOM, [line])
  end

  # Commands

  # Prompts for a string, and evaluate the string using the
  # Ruby interpreter.  Return TRUE if the string was evaluated
  # successfully, and FALSE if an exception occurred.
  def rubystring(f : Bool, n : Int32, k : Int32) : Result
    result, string = Echo.reply("Ruby code: ", nil)
    return result if result != Result::True
    return runruby(string)
  end

  # Defines a new MicroEMACS command that invokes a Ruby function.
  # The Ruby function *name* takes a single parameter, which
  # is the numeric argument to the command, or nil
  # if there is no argument.
  def rubycommand(f : Bool, n : Int32, key : Int32) : Result
    result, name = Echo.reply("Ruby function: ", nil)
    return result if result != Result::True

    # If this buffer has a mode, use its keymap;
    # otherwise use the global keymap.
    b = E.curb
    if b.modename.size == 0
      dprint("rubycommand: using global keymap instead of buffer #{b.name}")
      k = E.keymap
    else
      dprint("rubycommand: using buffer #{b.name} keymap")
      k = b.keymap
    end
    if k.name_bound?(name)
      Echo.puts("#{name} is already defined")
      return Result::False
    end

    # Bind the command to an unused key.  Eventually
    # the Ruby extension will call E.bind to bind
    # the method to a key.
    dprint("rubycommand: binding #{key} to #{name}")
    k.add(Kbd::RANDOM,
	  ->(f : Bool, n : Int32, k : Int32) {
             rubycall(name, f, n, key) },
	  name)
    return Result::True
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
