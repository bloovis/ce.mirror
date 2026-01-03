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

  # Allow buffer to have the same methods as the linked list.
  forward_missing_to @list
end
