#!/usr/bin/env ruby

def version
  if File.exist?('.fslckout')
    p = IO::popen(['fossil', 'info'])
    p.each do |line|
      if line =~ /^checkout:\s*(..........).*$/
	p.close
	return "fossil-" + $1
      end
    end
    p.close
    return "unknown"
  else
    p = IO::popen(['git', 'rev-parse', 'HEAD'])
    p.close
    return "git-" + p.read[0, 7]
  end
end

def iso_date
  Time.now.strftime("%Y-%m-%d")
end

File.open("version.cr", "w") do |f|
  f.puts "VERSION = \"#{iso_date} #{version}\""
end
