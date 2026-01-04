require "./ll"
require "./line"
require "./buffer"
require "./keymap"

module E
  extend self

  @@buffers = [] of Buffer

  def main
    ARGV.each do |arg|
      filename = arg
      b = Buffer.new(filename)
      @@buffers << b
      if b.readfile(filename)
	puts "Successfully read #{filename}:"
      else
	puts "Couldn't read #{filename}"
      end
      lineno = 1
      b.each do |s|
	puts "#{lineno}: #{s.text}"
	lineno += 1
      end
    end
  end

end

E.main
