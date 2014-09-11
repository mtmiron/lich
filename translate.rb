class XMLParser

	class GSLTag
		@@index ||= {}
		@@io_hook ||= nil
		@@io_trap ||= proc { |value| @@io = value }
		untrace_var :$stdout, @@io_trap
		trace_var :$stdout, @@io_trap
		attr_accessor :data
		def write(string)
			GSLTag.puts sprintf("%s%s%s", @open, string, @close)
		end
		def initialize(key, open = nil, close = nil, data = Hash.new)
			@open, @close, @data = open, close, data
			@@index[key.to_sym] = self
		end
		def GSLTag.puts(string)
			GSLTag.write sprintf("%s\r\n", string.chomp)
		end
		def GSLTag.write(string)
			if @@io_hook
				string = @@io_hook.call(string)
			end
			XMLParser.stream['main'].write string unless string.nil?
		end
		def GSLTag.[](key)
			@@index[key.to_sym]
		end
	end

#
# Anchors (interactive objects -- PCs, NPCs, items on the ground, etc.)
#
CALLBACKS['a'] = proc { GSLTag.puts "\034GSL" }
CALLBACKS['/a'] = proc { GSLTag.puts "\034GSM" }

#
# Obvious exits
#
GSLTag.new(:compass, "\034GSj", nil, { :dirs => Array.new, :dirsubs => { 'n' => 'A',
	'ne' => 'B',
	'e' => 'C', 
	'se' => 'D', 
	's' => 'E',
	'sw' => 'F',
	'w' => 'G',
	'nw' => 'H',
	'up' => 'I',
	'down' => 'J',
	'out' => 'K',
}})

CALLBACKS['compass'] = proc {
	GSLTag[:compass].data[:dirs].clear
}
CALLBACKS['dir'] = proc { |hash|
	GSLTag[:compass].data[:dirs].push GSLTag[:compass].data[:dirsubs][hash['value']]
}
CALLBACKS['/compass'] = proc {
	GSLTag[:compass].write GSLTag[:compass].data[:dirs].join
}

#
# NPCs
#
CALLBACKS['pushBold'] = proc {
	GSLTag.write "\034GSL"
}
CALLBACKS['popBold'] = proc {
	GSLTag.write "\034GSM"
}

#
# Game clock
#
GSLTag.new(:time, "\034GSq")
CALLBACKS['prompt'] = proc { |hash|
	GSLTag[:time].write hash[:time]
}

#
# Health/mana/spirit
#
GSLTag.new(:health, "\034GSX")
GSLTag.new(:mana, "\034GSZ")
GSLTag.new(:spirit, "\034GSY")

CALLBACKS['progressBar'] ||= {}
CALLBACKS['progressBar']['commonproc'] = proc { |key, hash|
	GSLTag[key].data[:cur], GSLTag[key].data[:max] = hash['text'].scan(/\d+/)
	GSLTag.write([ :health, :mana, :spirit ].inject("\034GSV") { |string, key|
		sprintf("%s%.10d%.10d", string, GSLTag[key].data[:max], GSLTag[key].data[:cur])
	} + proc {
		wounds = sprintf("%.28d", 0)
		scars = wounds.dup
		(1..28).step(2) { |n|
			istr = GSLTag[:injury].data[GSLTag[:injuries].data[:pos][n / 2]]
			sstr = GSLTag[:scar].data[GSLTag[:injuries].data[:pos][n / 2]]
			wounds[(-n - 1)..(-n)] = sprintf("%b", istr)
			scars[(-n - 1)..(-n)] = sprintf("%b", sstr)
		}
		sprintf("%010d%010d", "0b" + wounds, "0b" + scars)
	})
}
%w[ health mana spirit ].each { |sym|
	CALLBACKS['progressBar'][sym] = proc { |hash|
		CALLBACKS['progressBar']['commonproc'].call(sym.to_sym, hash)
	}
	CALLBACKS['progressBar']["#{sym}2"] = CALLBACKS['progressBar'][sym]
}

#
# Wounds and scars
#
GSLTag.new(:wounds, "\034GSa")
GSLTag.new(:scars, "\034GSb")
GSLTag.new(:injuries, nil, nil, Hash[ :pos,
	%w[ head neck rightArm leftArm rightLeg leftLeg rightHand leftHand chest abdomen back rightEye leftEye nsys ],
])
CALLBACKS['image'] = proc { |hash|
	GSLTag[hash['name'].slice(/injury|scar/i).downcase.to_sym].data[hash['id']] = hash['name'].slice(/\d/).to_i
}

#
# Stance
#
GSLTag.new(:stance, "\034GSg")
CALLBACKS['progressBar']['pbarStance'] = proc { |hash|
	GSLTag[:stance].write sprintf("%.10d", hash['value'])
}

#
# Room description (LOOK output)
#
GSLTag.new(:room, "\034%s%s%s")
CALLBACKS['style'] ||= {}
CALLBACKS['style']['roomName'] = proc {
	GSLTag.write "\034GSo\r\n"
	GSLTag[:room].instance_variable_set(:@open, "\034GSp\r\n")
}
CALLBACKS['style']['roomDesc'] = proc {
	GSLTag.write "\034GSH\r\n"
	GSLTag[:room].instance_variable_set(:@open, "\034GSI\r\n")
}
CALLBACKS['style'][''] = proc {
	if GSLTag[:room].instance_variable_get(:@open)
		GSLTag[:room].write nil
	end
	GSLTag[:room].instance_variable_set(:@open, nil)
}

#
# Formatted output data
#
GSLTag.new(:output, "\034GSw00008ignore this")
CALLBACKS['output'] = proc { |hash|
	GSLTag[:output].write nil
}

#
# Hard RT
#
GSLTag.new(:roundtime, "\034GSQ")
CALLBACKS['roundTime'] = proc { |hash|
	GSLTag[:roundtime].write hash['value']
}

#
# Hand contents and prepped spell
#
GSLTag.new(:right, "\034GSm")
GSLTag.new(:left, "\034GSl")
GSLTag.new(:spell, "\034GSn")
[ :right, :left, :spell ].each { |key|
	CALLBACKS[key.to_s] = proc {
		GSLTag[key].write nil
	}
}

#
# Status prompt
#
GSLTag.new(:prompt, "\034GSP", nil, { 'KNEELING' => 'GH',
	'STANDING' => 'T',
	'SITTING' => 'H',
	'PRONE' => 'G',
	'DEAD' => 'B',
	'STUNNED' => 'I',
	'HIDDEN' => 'N',
	'WEBBED' => 'C',
	'INVISIBLE' => 'D',
	'JOINED' => 'P',
	:array => [],
})

CALLBACKS[:indicator] = proc { |hash|
	if hash['visible'] == 'y'
		GSLTag[:prompt].data[:array].push GSLTag[:prompt].data[hash['id'].sub(/icon/i, '')]
	else
		GSLTag[:prompt].data[:array].delete GSLTag[:prompt].data[hash['id'].sub(/icon/i, '')]
	end
	GSLTag[:prompt].write GSLTag[:prompt].data[:array].uniq.join
}

end
