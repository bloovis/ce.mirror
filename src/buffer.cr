require "./ll"

@[Flags]
enum Bflags
  Changed
  Backup
  ReadOnly
end

class Buffer
  property list : LinkedList(Line)
  property flags : Bflags

  def initialize
    @list = LinkedList(Line).new
    @flags = Bflags::None
  end

  # Clears the buffer, and reads the file `filename` into the buffer.
  # Returns true if successful, false otherwise
  def readfile(filename : String) : Bool
    return false unless File.exists?(filename)
    @list.clear
    File.open(filename) do |f|
      while s = f.gets(chomp: true)
	l = Line.alloc(s)
	@list.push(l)
      end
    end
    return true
  end


  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
