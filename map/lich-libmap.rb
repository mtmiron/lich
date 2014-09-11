require 'pathfind' if !defined?(Pathfind)

class Map
	attr_accessor :pause
	include Pathfind

	def initialize(id, title, desc, paths, wayto={}, timeto={}, geo=nil, pause = nil)
		@id, @title, @desc, @paths, @wayto, @timeto, @geo = id, title, desc, paths, wayto, timeto, geo
		@pause = pause
		@@list.push(self)
	end
	def outside?
		@paths =~ /Obvious paths:/
	end
	def Map.uniq_new(id, title, desc, paths, wayto={}, timeto={}, geo=nil)
		chkre = /#{desc.strip.chop.gsub(/\.(?:\.\.)?/, '|')}/
		unless duplicate = @@list.find { |obj| obj.title == title and obj.desc =~ chkre and obj.paths == paths }
			return Map.new(id, title, desc, paths, wayto, timeto, geo)
		end
		return duplicate
	end
	def Map.uniq!
		list = []
		@@list.each { |room|
			chkre = /#{desc.strip.chop.gsub(/\.(?:\.\.)?/, '|')}/
			unless list.find { |duproom| duproom.desc =~ chkre and room.title == duproom.title and room.paths == duproom.paths }
				list.push(room)
			end
		}
		@@list = list
		nil
	end
	def Map.list
		@@list
	end
	def Map.[](val)
		if (val.class == Fixnum) or (val.class == Bignum)
			@@list.find { |room| room.id == val }
		else
			chkre = /#{val.strip.sub(/\.$/, '').gsub(/\.(?:\.\.)?/, '|')}/i
			chk = /#{Regexp.escape(val.strip)}/i
			@@list.find { |room| room.title =~ chk } or @@list.find { |room| room.desc =~ chk } or @@list.find { |room| room.desc =~ chkre }
		end
	end
	def Map.current
		ctitle = checkroom
		cdescre = /#{checkroomdescrip.strip.chop.gsub(/\.(?:\.\.)?/, '|')}/
		@@list.find { |room| room.desc =~ cdescre and room.title == ctitle and $_PATHSLINE_.chomp == room.paths }
	end
	def Map.reload
		Map.load
		Pathfind.reassoc_nodes
		Map.load_unique
		Pathfind.reassoc_nodes
		GC.start
	end
	def Map.load(file=($script_dir.to_s + "map.dat"))
		unless File.exists?(file)
			raise Exception.exception("MapDatabaseError"), "Fatal error: file `#{file}' does not exist!"
		end
		fd = File.open(file, 'rb')
		@@list = Marshal.load(fd.read)
		fd.close
		fd = nil
		@@list.each { |rm|
			rm.pause = nil
		}
		GC.start
	end
	def Map.load_unique(file=($script_dir.to_s + 'unique_map_movements.txt'))
		if File.exists?($script_dir + "unique_map_movements.txt")
			file = File.open($script_dir + "unique_map_movements.txt")
			udata = file.readlines.collect { |line| line.strip }.find_all { |line| line !~ /^#/ and !line.empty? }
			file.close
			newmini, mazerooms = [], []
			udata.shift
			until udata.first == 'END'
				mazerooms.push(udata.shift)
			end
			udata.shift
			pause_rooms = []
			udata.shift
			until udata.first == 'END'
				pause_rooms.push udata.shift
			end
			udata.shift

			while udata[0] =~ /\d+->\d+/
				rmfrom, rmto = udata.shift.split('->')
				if rmto.include?(':')
					rmto, time_estimate = rmto.split(':')
				else
					time_estimate = nil
				end 
				if rmfrom.nil? or rmto.nil? then respond "There's an error in the 'roomfrom->roomto' line of the script!"; exit end
				until (newline = udata.shift) == "END"
					newmini.push(newline)
				end
				if sroom = Pathfind.find_node(rmfrom.to_i) and droom = Pathfind.find_node(rmto.to_i)
					sroom.wayto[rmto.to_s] = StringProc.new(newmini.join("\n"))
					if time_estimate
						sroom.timeto ||= {}
						sroom.timeto[rmto.to_s] = time_estimate
					end
				else
					respond sprintf("Unrecoverable error, cannot identify one or both of the rooms with IDs %s and %s!", rmfrom, rmto)
					exit
				end
				newmini.clear
			end
			mazerooms.each { |num|
				node = Pathfind.find_node(num.to_i)
				node.wayto.clear
				node.maze = true
			}
			pause_rooms.each { |str|
				num, val = str.split(':')
				Pathfind.find_node(num.to_i).pause = val || 5
			}
		end
	end
	def Map.save(filename=($script_dir.to_s + "map.dat"))
		if File.exists?(filename)
			respond "File exists!  Backing it up before proceeding..."
			begin
				file = nil
				bakfile = nil
				file = File.open(filename, 'rb')
				bakfile = File.open(filename + ".bak", "wb")
				bakfile.write(file.read)
			rescue
				respond $!
			ensure
				file ? file.close : nil
				bakfile ? bakfile.close : nil
			end
		end
		begin
			file = nil
			file = File.open(filename, 'wb')
			file.write(Marshal.dump(@@list))
			respond "The current map database has been saved!"
		rescue
			respond $!
		ensure
			file ? file.close : nil
		end
		GC.start
	end
	def Map.smart_check
		error_rooms = []
		@@list.each { |room|
			if room.wayto.keys.include?(room.id.to_s)
				error_rooms.push("Room references itself as adjacent:\n#{room}")
			end
			room.wayto.dup.each { |torm, way|
				if way =~ /^(?:g |go )?(?:n|no|nor|nort|north)$/ and !(room.paths =~ /\bnorth,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:ne|northeast|northeas|northea|northe)$/ and !(room.paths =~ /\bnortheast,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:e|ea|eas|east)$/ and !(room.paths =~ /\beast,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:southeast|southeas|southea|southe)$/ and !(room.paths =~ /\bsoutheast,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:south|sout|sou|so|s)$/ and !(room.paths =~ /\bsouth,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:sw|southwest|southwes|southwe|southw)$/ and !(room.paths =~ /\bsouthwest,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:west|wes|we|w)$/ and !(room.paths =~ /\bwest,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:nw|northwest|northwes|northwe|northw)$/ and !(room.paths =~ /\bnorthwest,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:u|up)$/ and !(room.paths =~ /\bup,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				elsif way =~ /^(?:g |go )?(?:d|do|dow|down)$/ and !(room.paths =~ /\bdown,?\b/)
					puts("Dir error in room:\n#{room}\n... cannot reach room #{torm} by going #{way}!")
					room.wayto.delete(torm)
				end
			}
		}
		error_rooms
	end
	def Map.estimate_time(array)
		unless array.class == Array
			raise Exception.exception("MapError"), "Map.estimate_time was given something not an array!"
		end
		time = 0.00
		until array.length < 2
			croom = array.shift
			if t = Pathfind.find_node(croom).timeto[array.first.to_s]
				time += t.to_f
			else
				time += 0.5
			end
		end
		time
	end
	def get_wayto(int)
		dir = @wayto[int.to_s]
		if dir =~ /^\s*(?:n|north)\s*$/i then return N
		elsif dir =~ /^\s*(?:ne|northeast)\s*$/i then return NE
		elsif dir =~ /^\s*(?:e|east)\s*$/i then return E
		elsif dir =~ /^\s*(?:se|southeast)\s*$/i then return SE
		elsif dir =~ /^\s*(?:s|south)\s*$/i then return S
		elsif dir =~ /^\s*(?:sw|southwest)\s*$/i then return SW
		elsif dir =~ /^\s*(?:w|west)\s*$/i then return W
		elsif dir =~ /^\s*(?:nw|northwest)$\s*/i then return NW
		else return NODIR
		end
	end
	def cinspect
		sprintf("cstruct->id: %d;  cstruct->nadj: %d;  cstruct->x: %d;  cstruct->y: %d;  cstruct->rb_obj: %d", *(self.c_inspect))
	end
	def to_s
		"##{@id}:\n#{@title}\n#{@desc}\n#{@paths}"
	end
	def inspect
		self.instance_variables.collect { |var| var.to_s + "=" + self.instance_variable_get(var).inspect }.join("\n")
	end
end

class Room < Map
	private_class_method :new
	def Room.method_missing(*args)
		super(*args)
	end
end

class NilClass
	def +(arg)
		arg
	end
end

# proc objects can't be dumped, since an intrinsic part of what they are is the 'binding' environment... this is just a quick fix so that a proc object can be saved; it's identical to a proc except that it also carries around the string that created the proc, so when it's loaded from a Marshal dump the proc object is recreated from the original string.  Basically it's a way for each room to carry around a mini-script they can save and load with the rest of the map database info
class StringProc
	def initialize(string)
		@string = string
	end
	def kind_of?(type)
		Proc.new {}.kind_of? type
	end
	def class
		Proc
	end
	def call(*args)
		eval(@string, nil, "StringProc")
	end
	def _dump(depth = nil)
		@string
	end
	def StringProc._load(string)
		StringProc.new(string)
	end
end
