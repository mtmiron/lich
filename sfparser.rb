=begin

	sfparser.rb:

		Routines to convert SF metadata to Wizard format,
		as well as update Lich's tracking accordingly.

		The method names correspond to the XML element names
		that result in triggering them.
=end

module SFMetadata
	DIRMAP = {
		'out' => 'K',
		'ne' => 'B',
		'se' => 'D',
		'sw' => 'F',
		'nw' => 'H',
		'up' => 'I',
		'down' => 'J',
		'u' => 'I',
		'd' => 'J',
		'n' => 'A',
		'e' => 'C',
		's' => 'E',
		'w' => 'G',
	}
	MINDMAP = {
		/^clear as a bell$/io => 'A',
		/^fresh and clear$/io => 'B',
		/^clear$/io => 'C',
		/^muddled$/io => 'D',
		/^becoming numbed$/io => 'E',
		/^numbed$/io => 'F',
		/^fried$/io => 'G',
		/^saturated$/io => 'H',
	}
	@@bold = false
	@@objs = false
	@@streams = []

	# Hack to get around a threading issue
	def endline
		@@bold = @@objs = false
	end

	def a(hash={})
		$npcs.push(hash['noun']) if @@bold and @@objs and hash['noun']
	end

	def pushBold(hash={})
		@@bold = true
	end

	def popBold(hash={})
		@@bold = false
	end

	# The SF room window is only updated when moving; triggered by <pushStream id='room'/>
	def pushStream(hash={})
		$room_count += 1 if hash['id'] == 'room'
		@@streams.push(hash['id'])
	end

	def popStream(hash={})
		if hash['id']
			@@streams.delete(hash['id'])
		else
			@@streams.pop
		end
	end

	def current_stream
		@@streams.last
	end

	def room_objs(hash={})
		@@objs = true
		$npcs = []
		$room_items = []
	end

	def app(hash={})
		Char.init(hash['char'])
	end

	# Update the compass directions
	def dir(hash={})
		$_TAGHASH_['GSj'].concat(DIRMAP[hash['value']])
	end

	# Clear the compass directions in preparation for updating with the "dir" element
	def compass(hash={})
		$_TAGHASH_['GSj'] = String.new
	end

	# Update our tracking of the server's current time
	def prompt(hash={})
		$_TAGHASH_["GSq"] = hash['time'].to_i
		$_TIMEOFFSET_ = (Time.now.to_i - $_TAGHASH_["GSq"].to_i)
	end

	# Update when our roundtime will end
	def roundTime(hash={})
		$_TAGHASH_["GSQ"] = hash['value']
	end

	# Track soft RT as being the same as hard RT
	def castTime(hash={})
		roundTime(hash)
	end

	# Store current item in right hand
	def right(hash={})
		$_TAGHASH_['GSm'] = hash['noun']
	end

	# Store current item in left hand
	def left(hash={})
		$_TAGHASH_['GSl'] = hash['noun']
	end

	# Store current spell prepped
	def spell(hash={})
		$_TAGHASH_['GSn'] = /<spell[^>]*?>([\s\w]+)<\/spell>/o.match($_SERVERSTRING_).captures.first
	end

	# The action that should be taken is defined by the value of an element's "id" attribute
	# (notice that any spaces are replaced by underscores for proper compatibility)
	def call_id_as_meth(hash={})
		hash['id'].gsub!(' ', '_')
		send(hash['id'], hash) rescue()
	end

	# All of these elements have more than one action that needs to be taken,
	# and the "id" attribute should be used to determine what method applies
	[ :dialogData,
		:progressBar,
		:compDef,
		:component,
		:indicator,
		:label,
		:style,
	].each { |sym| alias_method(sym, :call_id_as_meth) rescue() }

	# Generic routine for updating status-prompt tracking
	def icon_parse(char, hash={})
		if hash['visible'].include?('y')
			$_TAGHASH_['GSP'].concat(char)
		else
			$_TAGHASH_['GSP'].gsub!(char,'')
		end
	end

	# Status prompt stuff; called as "<indicator id='IconSTANDING' visible='y'>", etc..
	# They all go through icon_parse().  The spaces allow distinguishing between 'GH' and 'G' or 'H'
	def IconKNEELING(hash={}); icon_parse(' GH ', hash); end
	def IconPRONE(hash={}); icon_parse(' G ', hash); end
	def IconSITTING(hash={}); icon_parse(' H ', hash); end
	def IconSTANDING(hash={}); icon_parse(' T ', hash); end
	def IconSTUNNED(hash={}); icon_parse(' I ', hash); end
	def IconHIDDEN(hash={}); icon_parse(' N ', hash); end
	def IconINVISIBLE(hash={}); icon_parse(' D ', hash); end
	def IconDEAD(hash={}); icon_parse(' B ', hash); end
	def IconWEBBED(hash={}); icon_parse(' C ', hash); end
	def IconJOINED(hash={}); icon_parse(' P ', hash); end

	# Update current room title
	def roomName(hash={})
		$roomtitle = $_SERVERSTRING_.gsub(/<[^>]+>/o,'')
		if $roomtitle.include?(',')
			$roomarea = $roomtitle.split(',').first
		end
	end

	# Update current room description
	def roomDesc(hash={})
		$roomdescription = $_SERVERSTRING_.slice(/<style id=['"]roomDesc['"]\/>.*<style id=['"]['"]\/>/o).gsub(/<[^>]+>/o,'')
	end

	def room_players(hash={})
		$pcs = $_SERVERSTRING_.scan(/noun=['"](\w+)['"]/o).flatten
	end

	def room_exits(hash={})
		$_PATHSLINE_ = $_SERVERSTRING_.gsub(/<[^>]+>/o, '')
	end

	# Update current character's level
	def yourLvl(hash={})
		Stats.level = hash['value'].slice(/\d+/o)
	end

	# Update character's current wound/scar info (see lich-lib.rb for Status.sf_update method)
	def image(hash={})
		if hash['id'] =~ /nsys|Hand|Arm|Leg|Eye|back|abdomen|chest|head|neck/o
			Status.sf_update(hash['id'], hash['name'])
		end
	end

	# Update char's current & max health
	def health(hash={})
		$_TAGHASH_['GSX'], $_TAGHASH_['MGSX'] = hash['text'].scan(/\d+/o)
	end

	# Update current & max mana
	def mana(hash={})
		$_TAGHASH_['GSZ'], $_TAGHASH_['MGSZ'] = hash['text'].scan(/\d+/o)
	end

	# Update current/max spirit
	def spirit(hash={})
		$_TAGHASH_['GSY'], $_TAGHASH_['MGSY'] = hash['text'].scan(/\d+/o)
	end

	# Update char's current/max stamina
	def stamina(hash={})
		$_TAGHASH_['stamina'], $_TAGHASH_['Mstamina'] = hash['text'].scan(/\d+/o)
	end

	# Called from <progressBar id="pbarStance">
	def pbarStance(hash={})
		$_TAGHASH_['GSg'] = hash['value']
	end

	# Called from <progressBar id='mindState'>
	def mindState(hash={})
		MINDMAP.keys.each { |key|
			if hash['text'] =~ key
				$_TAGHASH_['GSr'] = MINDMAP[key]
				return
			end
		}
		$_TAGHASH_['GSr'] = 'H'
	end

end
