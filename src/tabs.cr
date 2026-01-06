module Tabs
  @@tabsize = 8

  def self.tabsize : Int32
    @@tabsize
  end

  def self.tabsize=(n : Int32)
    @@tabsize = n
  end

  def self.detab(s : String)
    s.gsub(/([^\t]*)(\t)/) { $1 + " " * (@@tabsize - $1.size % @@tabsize) }
  end
end
