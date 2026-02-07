require "./keyboard"

# The `Macro` class records and plays back keyboard macros.
class Macro

  @buf : Array(Int32)
  @recording : Bool
  @read_index : Int32

  def initialize
    @buf = [] of Int32
    @recording = false
    @read_index = -1
  end

  # Methods for recording.

  # Starts recording a macro.  Clears the previous contents of the macro.
  def start_recording
    @recording = true
    @buf = [] of Int32
  end

  # Writes *key* to the macro.
  def write_key(key : Int32)
    return unless @recording
    @buf << key
  end

  # Writes the Ctrl-U numeric prefix *n* to the macro.
  def write_prefix(n : Int32)
    return unless @recording
    @buf << Kbd.ctrl('u')
    @buf << n
  end

  # Writes the string *s* to the macro.
  def write_string(s : String)
    return unless @recording
    s.each_char {|c| @buf << c.ord}
    @buf << 0
  end

  # Stops recording a macro.
  def stop_recording
    @recording = false
  end

  # Prints the contents of the macro to STDERR.
  def print
    @buf.each_with_index do |n, i|
      STDERR.puts("macro[#{i}] = #{Kbd.keyname(@buf[i])} (#{@buf[i].to_s(16)})")
    end
  end

  # Returns true if the macro is currently being recorded.
  def recording? : Bool
    return @recording
  end

  # Methods for playback.

  # Starts reading the macro.  Rewinds the read index to 0.
  def start_reading
    @read_index = 0
  end

  # Returns an Int32 value from the macro, or nil if
  # the end of the macro has been reached.
  def read_int : Int32 | Nil
    if @read_index < 0 || @read_index >= @buf.size
      return nil
    else
      key = @buf[@read_index]
      @read_index += 1
      return key
    end
  end

  # Returns a string from the macro, or nil if
  # the end of the macro has been reached.
  def read_string : String | Nil
    if @read_index < 0 || @read_index >= @buf.size
      return nil
    end
    str = String.build do |str|
      while @read_index < @buf.size
        ch = @buf[@read_index]
	@read_index += 1
        break if ch == 0
	str << ch.chr
      end
    end
    return str
  end

  # Stops reading the macro.
  def stop_reading
    @read_index = -1
  end

  # Returns true if the macro is currently being read.
  def reading?
    @read_index >= 0
  end
end

{% if flag?(:TEST) %}

m = Macro.new

m.start_recording
m.write_key('x'.ord)
m.write_prefix(16)
m.write_string("This is a string")
m.stop_recording

m.start_reading
k = m.read_int
if k
  puts "Read #{Kbd.keyname(k)}"
else
  puts "Expected key, got nil"
end
k = m.read_int
if !k.nil? && k == Kbd.ctrl('u')
  k = m.read_int
  if k
    puts "Read numeric prefix #{k}"
  else
    puts "Numeric prefix missing"
  end
else
  if k.nil?
    puts "Expected Ctrl-U, got nil"
  else
    puts "Expected Ctrl-U, got #{Kbd.keyname(k)}"
  end
end
s = m.read_string
if s
  puts "Read string '#{s}'"
else
  puts "Expected string, got nil"
end

{% end %} # flag TEST
