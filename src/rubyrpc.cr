require "json"

module RubyRPC
  @@process : Process | Nil

  extend self

  def start_server
    prog = "/usr/local/share/pe/server.rb"
    begin
      @@process = Process.new(prog,
			     nil,
                             input: Process::Redirect::Pipe,
                             output: Process::Redirect::Pipe,
                             error: Process::Redirect::Pipe,
			     shell: false)
      STDERR.puts "Created process for #{prog}"
    rescue IO::Error
      STDERR.puts "Unable to create process for #{prog}"
      @@process = nil
    end
  end

  def make_method_call(method : String, flag : Int32, prefix : Int32, key, strings : Array(String), id : Int32)
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


  def make_error_response(code : Int32, message : String, id : Int32)
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

  def make_normal_response(result : Int32, string : String, id : Int32)
    string = JSON.build do |json|
      json.object do
	json.field "jsonrpc", "2.0"
	json.field "id", id
	json.field "result", result
	json.field "string", string
      end
    end
  end


  def is_call(obj : JSON::Any)
    return !obj["method"]?.nil?
  end

  def parse_method_call(obj : JSON::Any)
    method = obj["method"]?
    if method
      STDERR.puts "method: #{method.as_s}"
    end
    id = obj["id"]?
    if id
      STDERR.puts "id: #{id.as_i}"
    end
    params = obj["params"]?
    if params
      h = params.as_h
      flag = h["flag"].as_i?
      STDERR.puts "flag: #{flag}" if flag
      prefix = h["prefix"].as_i?
      STDERR.puts "prefix: #{prefix}" if prefix
      key = h["key"].as_i?
      STDERR.puts "prefix: 0x#{key.to_s(16)}" if key
      strings = h["strings"]
      if strings
	STDERR.puts "strings:"
	a = strings.as_a
	a.each {|s| STDERR.puts "  #{s.as_s}"}
      end
    end
  end

  def is_error(obj : JSON::Any)
    return !obj["error"]?.nil?
  end

  def parse_error_response(obj : JSON::Any)
    id = obj["id"]?
    if id
      STDERR.puts "id: #{id.as_i}"
    end
    params = obj["error"]?
    if params
      h = params.as_h
      code = h["code"].as_i?
      STDERR.puts "code: #{code}" if code
      message = h["message"].as_s?
      STDERR.puts "message: #{message}" if message
    end
  end

  def is_result(obj : JSON::Any)
    return !obj["result"]?.nil?
  end

  def parse_result_response(obj : JSON::Any)
    id = obj["id"]?
    if id
      STDERR.puts "id: #{id.as_i}"
    end
    result = obj["result"]?
    if result
      STDERR.puts "result: #{result.as_i}"
    end
    string = obj["string"]?
    if string
      STDERR.puts "string: #{string.as_s}"
    end
  end

  def read_rpc_message(f : IO) : JSON::Any | Nil
    s = f.gets
    return nil unless s
    len = s.to_i
    STDERR.puts "got len #{len}"
    slice = Bytes.new(len)
    f.read(slice)
    jsonbuf = String.new(slice)
    STDERR.puts "got json '#{jsonbuf}'"
    return JSON.parse(jsonbuf)
  end

  # Runs the Ruby command *name*, passing in the usual command
  # parameters *f*, *n*, and *k*, and returning its result.
  # This is just the scaffold for a future working implementation.
  def command(name : String, f : Bool, n : Int32, k : Int32) : Result
    Echo.puts("runruby: name #{name}, f #{f}, n #{n}, k 0x#{k.to_s(16)}")
    return Result::True
  end

end
