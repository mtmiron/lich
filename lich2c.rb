#!/usr/bin/env ruby
# Converts the Ruby source files into a C source file for compilation; very quick-and-dirty, probably won't work on any system but the author's

#files = [ "zlib.rb", "lichnet-deps.rb", "libhooks.rb", "libcharsheet.rb", "lich-lib.rb", "libsettings.rb", "lich-libcritter.rb", "stringformatting.rb", "lich-libmap.rb", "lich-libmatch.rb", "lich.rb" ]
#files = [ "libhooks.rb", "libcharsheet.rb", "lich-lib.rb", "libsettings.rb", "lich-libcritter.rb", "stringformatting.rb", "lich-libmap.rb", "lich-libmatch.rb", "lich.rb" ]


def puts(*str)
	print("> #{__FILE__}: ") unless str.empty?
	$stdout.puts(*str)
end

puts "Reading file list from `#{File.join(Dir.pwd, 'rbflist.txt')}'..."
files = File.open("rbflist.txt") { |f| f.readlines.collect { |line| line.strip }.reject { |line| line.empty? or line =~ /^\s*#/ } }

if !ARGV.find { |arg| arg =~ /^--?w(?:indows)?$/i }
	dir = "./"
else
	if ENV['OS'] !~ /win/i
		if `id -un` =~ /fallen/
			dir = "/home/fallen/progs/lich/"
		else
			dir = "./"
		end
	end
end

Dir.chdir(dir)
data = '$".push(' + files.collect { |f| "\"#{f}\"" }.join(', ') + ")\n"
#puts

files.each { |fname|
	dir = File.expand_path(dir)
	puts "Reading Ruby source file `#{File.join(dir, fname)}'..."
	data += File.open(File.join(dir, fname)) { |file| file.read.gsub(/\n\s*#[^\{][^\n]*\n|\n=begin.+\n=end/m, "\n").gsub("\t", '') } + "\n"
#	data += "\n"
#	data += file.read.gsub(/\n\s*#\s[^\n]+|=begin.*=end/m, "\n")
#	file.close
}
if ARGV.find { |arg| arg =~ /^--test$/ }
	puts "Dumping to lichrb-test.rb"
	file = File.open(dir + "lichrb-test.rb", 'w')
	file.puts data
	file.close
	exit
end
file = File.open("lichrb.c", 'w')
file.print "void Init_lich_frame()\n{"
#file.puts "VALUE str = rb_str_new2(#{data.dump.gsub('\#', '#')});"
file.puts "\n\trb_compile_string(\"Lich\", rb_str_new2(#{data.dump.gsub("\\#", "#")}), 0);\nreturn;\n}"
file.close
puts "Ruby source dumped to C file `#{File.expand_path file.path}' for compilation."
puts
exit
