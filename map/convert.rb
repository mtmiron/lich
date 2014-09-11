#!/usr/bin/env ruby

SYMS = [ :@id, :@area,
	:@title, :@desc,
	:@adj,
]

require 'lich-libmap.rb'

$script_dir = File.join(Dir.pwd, "/")
Map.reload
Pathfind.trace_field_positions

$stderr.puts "Total rooms: " + Map.list.length.to_s


# Output basic info
for room in Map.list
	str = sprintf("[%d]\r\ntitle=%s\r\ngeo=%s\r\nx=%d\r\ny=%d\r\n",
	              room.id,room.title,room.geo,room.x_val,room.y_val)
	puts str
end

# Now that all nodes are printed, output adjacent info
for room in Map.list
	puts sprintf("[%d]\r\n", room.id)

	for ary in room.wayto
		print sprintf("adj=%s,", ary[0])
		dir = ary[1]

		if !dir.kind_of? String
			print "(unique)"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:n|north)\s*$/i
			print "n"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:ne|northeast)\s*$/i
			print "ne"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:e|east)\s*$/i
			print "e"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:se|southeast)\s*$/i
			print "se"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:s|south)\s*$/i
			print "s"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:sw|southwest)\s*$/i
			print "sw"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:w|west)\s*$/i
			print "w"
		elsif dir =~ /^\s*(?:go|climb|clim|cli|g)?\s*(?:nw|northwest)$\s*/i
			print "nw"
		else
			print sprintf("%s", (ary[1].kind_of?(Proc) ? "(unique)" : ary[1]))
		end
		puts "\r\n"

	end

end
