# Source:
# https://github.com/crystal-lang/crystal/blob/3b74bc91771842035c5353a1725219405b8dd528/src/crystal/pointer_linked_list.cr
#
# Doubly linked list of `T` structs referenced as pointers.
# `T` that must include `LinkedList::Node`.
struct LinkedList(T)
  getter head : Pointer(T) = Pointer(T).null

  module Node
    macro included
      property previous : ::Pointer(self) = ::Pointer(self).null
      property next : ::Pointer(self) = ::Pointer(self).null
    end
  end

  @[AlwaysInline]
  protected def self.link(p : Pointer(T), q : Pointer(T)) : Nil
    p.value.next = q
    q.value.previous = p
  end

  @[AlwaysInline]
  protected def self.insert_impl(new : Pointer(T), prev : Pointer(T), _next : Pointer(T)) : Nil
    prev.value.next = new
    new.value.previous = prev
    new.value.next = _next
    _next.value.previous = new
  end

  # Returns `true` if the list is empty, otherwise false.
  def empty? : Bool
    @head.null?
  end

  # Prepends *node* to the head of the list.
  def unshift(node : Pointer(T)) : Nil
    if !empty?
      typeof(self).insert_impl node, @head.value.previous, @head
    else
      node.value.previous = node
      node.value.next = node
    end
    @head = node
  end

  # Appends *node* to the tail of the list.
  def push(node : Pointer(T)) : Nil
    if empty?
      node.value.previous = node
      node.value.next = node
      @head = node
    else
      typeof(self).insert_impl node, @head.value.previous, @head
    end
  end

  # Removes *node* from the list.
  def delete(node : Pointer(T)) : Nil
    _next = node.value.next

    if node != _next
      @head = _next if @head == node
      typeof(self).link node.value.previous, _next
    else
      @head = Pointer(T).null
    end
  end

  # Removes and returns head from the list, yields if empty
  def shift(&)
    if empty?
      yield
    else
      @head.tap { |t| delete(t) }
    end
  end

  # Returns and returns head from the list, `nil` if empty.
  def shift?
    shift { nil }
  end

  # Removes and returns tail from the list, yields if empty.
  def pop(&)
    if !empty?
      h = @head
      t = (h.value.previous || h).tap { |t| delete(t) }
    else
      yield
    end
  end

  # Removes and returns tail from the list, `nil` if empty.
  def pop?
    pop { nil }
  end

  # Iterates the list.
  def each(&) : Nil
    return if empty?

    node = @head
    loop do
      _next = node.value.next
      yield node
      break if _next == @head
      node = _next
    end
  end

  # Iterates the list before clearing it.
  def consume_each(&) : Nil
    each { |node| yield node }
    @head = Pointer(T).null
  end

  ###
  ### Methods I added start here.
  ###

  # Finds the first node for which the block returns true.
  def find(&) : Pointer(T) | Nil
    return nil if empty?

    node = @head
    loop do
      _next = node.value.next
      return node if yield node
      return nil if _next == @head
      node = _next
    end
  end

  # Inserts line `_new` after line `_prev`.
  def insert_after(_prev : Pointer(T), _new : Pointer(T)) : Nil
    typeof(self).insert_impl(_new, _prev, _prev.value.next)
  end

  # Inserts line `_new` before line `_next`.
  def insert_before(_next : Pointer(T), _new : Pointer(T)) : Nil
    typeof(self).insert_impl(_new, _next.value.previous, _next)
  end

  # Clears the list.
  def clear
    @head = Pointer(T).null
  end
end
