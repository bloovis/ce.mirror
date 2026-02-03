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

  def start_recording
    @recording = true
  end

  def write_key(key : Int32)
    return unless @recording
    @buf << key
  end

  def write_prefix(n : Int32)
    return unless @recording
    @buf << Kbd.ctrl('u')
    @buf << n
  end

  def write_string(s : String)
    return unless @recording
    s.each_char {|c| @buf << c.ord}
    @buf << 0
  end

  def stop_recording
    @recording = false
    @buf.each_with_index do |n, i|
      STDERR.puts("macro[#{i}] = #{Kbd.keyname(@buf[i])} (#{@buf[i].to_s(16)})")
    end
  end

  def recording? : Bool
    return @recording
  end

  # Methods for playback.

  def start_reading
    @read_index = 0
  end

  def read_int : Int32 | Nil
    if @read_index < 0 || @read_index >= @buf.size
      return nil
    else
      key = @buf[@read_index]
      @read_index += 1
      return key
    end
  end

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

  def stop_reading
    @read_index = -1
  end

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
