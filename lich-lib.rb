# The vast majority of script 'commands' are defined here.  A lot of random garbage is tossed in because over the long months I've been writing Lich, I've been learning as I added to it.  For now I'm too lazy to clean it up, so it's only real use is to serve as an example (if you really want to, go ahead and try to use this to extend your own project, but good luck, lol).  If you want to peek at what happens when you use a command in a script, just do a search for 'def (command)' [replace (command) with the command you want to look at, of course].

at_exit { Process.waitall }

class NilClass
	def dup
		nil
	end
	def method_missing(*args)
		nil
	end
end

module Enumerable
	def qfind(obj)
		find { |el| el.match obj }
	end
end

class String
	def split_as_list
		string = self
		string.sub!(/^You (?:also see|notice) |^In the .+ you see /, ',')
		string.sub('.','').sub(/ and (an?|some|the)/, ', \1').split(',').reject { |str|
			str.strip.empty?
		}.collect { |str| str.lstrip }
	end
end

		
class Char
	@@cha ||= nil
	@@name ||= nil
	private_class_method :new
	def Char.init(name)
		@@name == nil ? @@name = name.strip : @@name.dup
	end
	def Char.name
		@@name or $_TAGHASH_['GSB'].slice(/[A-Z][a-z]+/)
	end
	def Char.health(*args)
		checkhealth(*args)
	end
	def Char.mana(*args)
		checkmana(*args)
	end
	def Char.spirit(*args)
		checkspirit(*args)
	end
	def Char.maxhealth
		Object.module_eval { maxhealth }
	end
	def Char.maxmana
		Object.module_eval { maxmana }
	end
	def Char.maxspirit
		Object.module_eval { maxspirit }
	end
	def Char.stamina(*args)
		checkstamina(*args)
	end
	def Char.maxstamina
		Object.module_eval { maxstamina }
	end
	def Char.cha(val=nil)
		val == nil ? @@cha : @@cha = val
	end
	def Char.dump_info
		save = Thread.critical
		begin
			Marshal.dump([
				Spell.detailed?,
				Spell.serialize,
				Spellsong.serialize,
				Stats.serialize,
				Skills.serialize,
				Spells.serialize,
				Gift.serialize,
				Society.serialize,
			])
		ensure
			Thread.critical = save
		end
	end
	def Char.load_info(string)
		save = Char.dump_info
		begin
			Spell.load_detailed,
			Spell.load_active,
			Spellsong.load_serialized,
			Stats.load_serialized,
			Skills.load_serialized,
			Spells.load_serialized,
			Gift.load_serialized,
			Society.load_serialized = Marshal.load(string)
		rescue
			raise $! if string == save
			string = save
			retry
		end
	end
	def Char.method_missing(meth, *args)
		[ Stats, Skills, Spellsong, Society ].each { |klass|
			begin
				result = klass.__send__(meth, *args)
				return result
			rescue
			end
		}
		raise NoMethodError
	end
end

class Society
	@@status ||= String.new
	@@rank ||= 0
	def Society.serialize
		[@@status,@@rank]
	end
	def Society.load_serialized=(val)
		@@status,@@rank = val
	end
	def Society.status=(val)
		@@status = val
	end
	def Society.status
		@@status.dup
	end
	def Society.rank=(val)
		if val =~ /Master/
			if @@status =~ /Voln/ then @@rank = 26 elsif @@status =~ /Council of Light/ then @@rank = 20 else @@rank = val.to_i end
		else
			@@rank = val.slice(/[0-9]+/).to_i
		end
	end
	def Society.step
		@@rank
	end
	def Society.member
		@@status.dup
	end
	def Society.rank
		@@rank
	end
end

class Spellsong
	@@renewed ||= Time.at(Time.now.to_i - 1200)
	def Spellsong.renewed
		@@renewed = Time.now
	end
	def Spellsong.renewed=(val)
		@@renewed = val
	end
	def Spellsong.renewed_at
		@@renewed
	end
	def Spellsong.timeleft
		if Time.now - @@renewed > Spellsong.duration
			@@renewed = Time.now
		end
		(Spellsong.duration - (Time.now - @@renewed)) / 60.00
	end
	def Spellsong.serialize
		Spellsong.timeleft
	end
	def Spellsong.load_serialized=(old)
		Thread.new {
			n = 0
			while Stats.level == 0
				sleep 0.25
				n += 1
				break if n >= 4
			end
			unless n >= 4
				@@renewed = Time.at(Time.now.to_f - (Spellsong.duration - old * 60.00))
			else
				@@renewed = Time.now
			end
		}
		nil
	end
	def Spellsong.duration
		total = 120
		1.upto(Stats.level.to_i) { |n|
			if n < 26
				total += 4
			elsif n < 51
				total += 3
			elsif n < 76
				total += 2
			else
				total += 1
			end
		}
		(total + Stats.log[1].to_i + (Stats.inf[1].to_i * 3) + (Skills.mltelepathy.to_i * 2))
	end
	def Spellsong.tonisdodgebonus
		thresholds = [1,2,3,5,8,10,14,17,21,26,31,36,42,49,55,63,70,78,87,96]
		bonus = 20
		thresholds.each { |val| if Skills.elair >= val then bonus += 1 end }
		bonus
	end
	def Spellsong.tonishastebonus
		bonus = -1
		thresholds = [30,75]
		thresholds.each { |val| if Skills.elair >= val then bonus -= 1 end }
		bonus
	end
	def Spellsong.mirrorsdodgebonus
		20 + ((Spells.bard - 19) / 2).round
	end
	def Spellsong.mirrorscost
		[19 + ((Spells.bard - 19) / 5).truncate, 8 + ((Spells.bard - 19) / 10).truncate]
	end
	def Spellsong.depressionpushdown
		20 + Skills.mltelepathy
	end
	def Spellsong.depressionslow
		thresholds = [10,25,45,70,100]
		bonus = -2
		thresholds.each { |val| if Skills.mltelepathy >= val then bonus -= 1 end }
		bonus
	end
	def Spellsong.sonicarmordurability
		210 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
	end
	def Spellsong.sonicbladedurability
		160 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
	end
	def Spellsong.sonicshielddurability
		125 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
	end
	def Spellsong.sonicbonus
		(Spells.bard / 2).round
	end
	def Spellsong.sonicarmorbonus
		Spellsong.sonicbonus + 15
	end
	def Spellsong.sonicbladebonus
		Spellsong.sonicbonus + 10
	end
	def Spellsong.sonicshieldbonus
		Spellsong.sonicbonus + 10
	end
	def Spellsong.valorbonus
		10 + (Spells.bard / 2).round
	end
	def Spellsong.valorcost
		[10 + (Spellsong.valorbonus / 2), 3 + (Spellsong.valorbonus / 5)]
	end
	def Spellsong.luckcost
		[6 + ((Spells.bard - 6) / 4),(6 + ((Spells.bard - 6) / 4) / 2).round]
	end
	def Spellsong.holdingtargets
		1 + ((Spells.bard - 1) / 7).truncate
	end
end

class Skills
	@@twoweaponcombat ||= 0
	@@armoruse ||= 0
	@@shielduse ||= 0
	@@combatmaneuvers ||= 0
	@@edgedweapons ||= 0
	@@bluntweapons ||= 0
	@@twohandedweapons ||= 0
	@@rangedweapons ||= 0
	@@thrownweapons ||= 0
	@@polearmweapons ||= 0
	@@brawling ||= 0
	@@ambush ||= 0
	@@multiopponentcombat ||= 0
	@@combatleadership ||= 0
	@@physicalfitness ||= 0
	@@dodging ||= 0
	@@arcanesymbols ||= 0
	@@magicitemuse ||= 0
	@@spellaiming ||= 0
	@@harnesspower ||= 0
	@@emc ||= 0
	@@mmc ||= 0
	@@smc ||= 0
	@@elair ||= 0
	@@elearth ||= 0
	@@elfire ||= 0
	@@elwater ||= 0
	@@slblessings ||= 0
	@@slreligion ||= 0
	@@slsummoning ||= 0
	@@sldemonology ||= 0
	@@slnecromancy ||= 0
	@@mldivination ||= 0
	@@mlmanipulation ||= 0
	@@mltelepathy ||= 0
	@@mltransference ||= 0
	@@mltransformation ||= 0
	@@survival ||= 0
	@@disarmingtraps ||= 0
	@@pickinglocks ||= 0
	@@stalkingandhiding ||= 0
	@@perception ||= 0
	@@climbing ||= 0
	@@swimming ||= 0
	@@firstaid ||= 0
	@@trading ||= 0
	@@pickpocketing ||= 0
	def Skills.serialize
		[@@twoweaponcombat, @@armoruse, @@shielduse, @@combatmaneuvers, @@edgedweapons, @@bluntweapons, @@twohandedweapons, @@rangedweapons, @@thrownweapons, @@polearmweapons, @@brawling, @@ambush, @@multiopponentcombat, @@combatleadership, @@physicalfitness, @@dodging, @@arcanesymbols, @@magicitemuse, @@spellaiming, @@harnesspower, @@emc, @@mmc, @@smc, @@elair, @@elearth, @@elfire, @@elwater, @@slblessings, @@slreligion, @@slsummoning, @@sldemonology, @@slnecromancy, @@mldivination, @@mlmanipulation, @@mltelepathy, @@mltransference, @@mltransformation, @@survival, @@disarmingtraps, @@pickinglocks, @@stalkingandhiding, @@perception, @@climbing, @@swimming, @@firstaid, @@trading, @@pickpocketing]
	end
	def Skills.load_serialized=(array)
		@@twoweaponcombat, @@armoruse, @@shielduse, @@combatmaneuvers, @@edgedweapons, @@bluntweapons, @@twohandedweapons, @@rangedweapons, @@thrownweapons, @@polearmweapons, @@brawling, @@ambush, @@multiopponentcombat, @@combatleadership, @@physicalfitness, @@dodging, @@arcanesymbols, @@magicitemuse, @@spellaiming, @@harnesspower, @@emc, @@mmc, @@smc, @@elair, @@elearth, @@elfire, @@elwater, @@slblessings, @@slreligion, @@slsummoning, @@sldemonology, @@slnecromancy, @@mldivination, @@mlmanipulation, @@mltelepathy, @@mltransference, @@mltransformation, @@survival, @@disarmingtraps, @@pickinglocks, @@stalkingandhiding, @@perception, @@climbing, @@swimming, @@firstaid, @@trading, @@pickpocketing = array
	end
	def Skills.method_missing(arg1, arg2='')
		instance_eval("@@#{arg1}#{arg2}", if Script.self then Script.self.name else "Lich" end)
	end
	def Skills.to_bonus(ranks)
		bonus = 0
		while ranks > 0
			if ranks > 40
				bonus += (ranks - 40)
				ranks = 40
			elsif ranks > 30
				bonus += (ranks - 30) * 2
				ranks = 30
			elsif ranks > 20
				bonus += (ranks - 20) * 3
				ranks = 20
			elsif ranks > 10
				bonus += (ranks - 10) * 4
				ranks = 10
			else
				bonus += (ranks * 5)
				ranks = 0
			end
		end
		bonus
	end
end

class Spells
	@@minorelemental ||= 0
	@@majorelemental ||= 0
	@@minorspiritual ||= 0
	@@majorspiritual ||= 0
	@@wizard ||= 0
	@@sorcerer ||= 0
	@@ranger ||= 0
	@@paladin ||= 0
	@@empath ||= 0
	@@cleric ||= 0
	@@bard ||= 0
	def Spells.method_missing(arg1, arg2='')
		instance_eval("@@#{arg1}#{arg2}")
	end
	def Spells.minorspirit
		@@minorspiritual
	end
	def Spells.minorspirit=(val)
		@@minorspiritual = val
	end
	def Spells.majorspirit
		@@majorspiritual
	end
	def Spells.majorspirit=(val)
		@@majorspiritual = val
	end
	def Spells.get_circle_name(num)
		val = num.to_s
		if val == "1" then "Minor Spirit"
		elsif val == "2" then "Major Spirit"
		elsif val == "3" then "Cleric"
		elsif val == "4" then "Minor Elemental"
		elsif val == "5" then "Major Elemental"
		elsif val == "6" then "Ranger"
		elsif val == "7" then "Sorcerer"
		elsif val == "9" then "Wizard"
		elsif val == "10" then "Bard"
		elsif val == "11" then "Empath"
		elsif val == "16" then "Paladin"
		elsif val == "66" then "Death"
		elsif val == "65" then "Imbedded Enchantment"
		elsif val == "96" then "Combat Maneuvers"
		elsif val == "98" then "Order of Voln"
		elsif val == "99" then "Council of Light"
		elsif val == "cm" then "Combat Maneuvers"
		elsif val == "mi" then "Miscellaneous"
		else 'Unknown Circle' end
	end
	def Spells.active
		Spell.active
	end
	def Spells.known
		ary = []
		Spell.list.each { |sp_obj|
			circlename = Spells.get_circle_name(sp_obj.circle)
			sym = circlename.delete("\s").downcase
			ranks = Spells.send(sym).to_i rescue()
			next unless ranks.nonzero?
			num = sp_obj.num.to_s[-2..-1].to_i
			ary.push sp_obj if ranks >= num
		}
		ary
	end
	def Spells.serialize
		[@@minorelemental,@@majorelemental,@@minorspiritual,@@majorspiritual,@@wizard,@@sorcerer,@@ranger,@@paladin,@@empath,@@cleric,@@bard]
	end
	def Spells.load_serialized=(val)
		@@minorelemental,@@majorelemental,@@minorspiritual,@@majorspiritual,@@wizard,@@sorcerer,@@ranger,@@paladin,@@empath,@@cleric,@@bard = val
	end
end

class Spell
	@@active ||= Array.new
	@@list ||= Array.new
	@@active_loaded ||= false
	@@detailed ||= true
	attr_reader :timestamp, :num, :name, :duration, :timeleft, :msgup, :msgdn, :stacks, :circle, :circlename, :selfonly, :cost
	def initialize(num,name,duration,cost,misc,msgup,msgdn)
		@name,@duration,@cost,@msgup,@msgdn = name,duration,cost,msgup,msgdn
		if num.to_i.nonzero? then @num = num.to_i else @num = num end
		@timestamp = Time.now
		@selfonly = misc.include?('1')
		@stacks = misc.include?('~')
		@active = false
		@timeleft = 0
		@msgup = msgup
		@msgdn = msgdn
		@circle = (num.to_s.length == 3 ? num.to_s[0..0] : num.to_s[0..1])
		@circlename = Spells.get_circle_name(@circle)
		@@list.push(self) unless @@list.find { |spell| spell.name == @name }
	end
	def Spell.serialize
		spell = nil; @@active.each { |spell| spell.touch }
		@@active
	end
	def Spell.load_active=(data)
		data.each { |oldobject|
			spell = @@list.find { |newobject| oldobject.name == newobject.name }
			unless @@active.include?(spell)
				spell.timeleft = oldobject.timeleft
				spell.active = true
				@@active.push(spell)
			end
		}
	end
	def Spell.load_detailed=(data)
		@@detailed = data
	end
	def Spell.detailed?
		@@detailed
	end
	def Spell.increment_detailed
		@@detailed = !@@detailed
	end
	def active=(val)
		@active = val
	end
	def Spell.active
		@@active
	end
	def Spell.list
		@@list
	end
	def Spell.upmsgs
		@@list.collect { |spell| spell.msgup }
	end
	def Spell.dnmsgs
		@@list.collect { |spell| spell.msgdn }
	end
	def timeleft=(val)
		@timeleft = val
		@timestamp = Time.now
	end
	def touch
		if @duration.to_s == "Spellsong.timeleft"
			@timeleft = Spellsong.timeleft
		else
			@timeleft = @timeleft - ((Time.now - @timestamp) / 60.00)
			if @timeleft.to_f <= 0
				self.putdown
				return 0.0
			end
		end
		@timestamp = Time.now
		@timeleft
	end
	def Spell.[](val)
		if val.class == Spell
			val
		elsif val.class == Fixnum
			@@list.find { |spell| spell.num == val }
		else
			if ret = @@list.find { |spell| spell.name =~ /^#{val}$/i } then ret
			elsif ret = @@list.find { |spell| spell.name =~ /^#{val}/i } then ret
			else @@list.find { |spell| spell.msgup =~ /#{val}/i or spell.msgdn =~ /#{val}/i } end
		end
	end
	def Spell.active?(val)
		Spell[val].active?
	end
	def active?
		touch
		@active
	end
	def minsleft
		touch
	end
	def secsleft
		touch * 60
	end
	def to_s
		@name.to_s
	end
	def putup
		touch
		@stacks ? @timeleft += eval(@duration).to_f : @timeleft = eval(@duration).to_f
		if @timeleft > 240 then @timeleft = 239.983 end
		@@active.push(self) unless @@active.include?(self)
		@active = true
	end
	def putdown
		@active = false
		@timeleft = 0
		@timestamp = Time.now
		@@active.delete(self)
	end
	def remaining
		self.touch.as_time
	end
end

class Stats
	@@race ||= 'unknown'
	@@prof ||= 'unknown'
	@@gender ||= 'unknown'
	@@age ||= 0
	@@exp ||= 0
	@@level ||= 0
	@@str ||= [0,0]
	@@con ||= [0,0]
	@@dex ||= [0,0]
	@@agi ||= [0,0]
	@@dis ||= [0,0]
	@@aur ||= [0,0]
	@@log ||= [0,0]
	@@int ||= [0,0]
	@@wis ||= [0,0]
	@@inf ||= [0,0]
	def Stats.method_missing(arg1, arg2='')
		if arg2.class == Array
			instance_eval("@@#{arg1}[#{arg2.join(',')}]", if Script.self then Script.self.name else "Lich" end)
		elsif arg2.to_s =~ /^\d+$/
			instance_eval("@@#{arg1}#{arg2}", if Script.self then Script.self.name else "Lich" end)
		elsif arg2.empty?
			instance_eval("@@#{arg1}", if Script.self then Script.self.name else "Lich" end)
		else
			instance_eval("@@#{arg1}'#{arg2}'", if Script.self then Script.self.name else "Lich" end)
		end
	end
	def Stats.serialize
		[@@race,@@prof,@@gender,@@age,@@exp,@@level,@@str,@@con,@@dex,@@agi,@@dis,@@aur,@@log,@@int,@@wis,@@inf]
	end
	def Stats.load_serialized=(array)
		@@race,@@prof,@@gender,@@age,@@exp,@@level,@@str,@@con,@@dex,@@agi,@@dis,@@aur,@@log,@@int,@@wis,@@inf = array
	end
end

class Gift
	@@began ||= Time.now
	@@timer ||= 0
	@@running ||= false
	@@stopwatch ||= Time.now
	@@tracked ||= false
	def Gift.serialize
		[@@began,@@timer]
	end
	def Gift.load_serialized=(array)
		@@tracked = true
		@@began,@@timer = array
	end
	def Gift.touch
		over = @@began + 604800
		if Time.now > over
			@@timer = 0
			@@running = false
			@@stopwatch = Time.now
		end
		Gift.stopwatch
	end
	def Gift.stopwatch
		if $_TAGHASH_['GSr'] =~ /^A/
			if @@running then @@timer += (Time.now.to_f - @@stopwatch.to_f) end
			@@running = false
		else
			if @@running
				@@timer += (Time.now.to_f - @@stopwatch.to_f)
			end
			@@running = true
			@@stopwatch = Time.now
		end
	end
	def Gift.remaining
		Gift.touch
		unless @@tracked then return 0 end
		21600 - @@timer
	end
	def Gift.restarts_on
		@@began + 604800
	end
	def Gift.ended
		@@timer = 21601
	end
	def Gift.started
		@@began = Time.now
		@@timer = 0
		@@stopwatch = Time.now
		Gift.stopwatch
	end
end

class Lich
	def Lich.reload_settings
		begin
			if Char.name
				file = File.open($lich_dir + "settings-#{Char.name}.txt")
			else
				file = File.open($lich_dir + "settings.txt")
			end
			file.readlines.collect { |line| line.strip }.find_all { |line| line !~ /^#/ and !line.empty? }.each { |line|
				set, val = line.split(':').collect { |piece| piece.strip }
				if val.include?(',')
					Lich.module_eval("@@#{set} = ['#{val.gsub(/, |,/, "', '")}']", if Script.self then Script.self.name else "Lich" end)
				else
					Lich.module_eval("@@#{set} = '#{val}'", if Script.self then Script.self.name else "Lich" end)
				end
			}
		rescue SystemCallError
			file ? file.close : nil
			if Char.name
				file = File.open($lich_dir + "settings-#{Char.name}.txt", 'w')
			else
				file = File.open($lich_dir + "settings.txt", 'w')
			end
			file.write %[# These are your Lich settings.  Note that each character will have their own file called "settings-(charname).txt" if you're using Lich with GemStone.  If you're using it with another MUD, the template file (just plain "settings.txt") will be used globally since Lich has no clue what your char name is.  You can access any of these from within a script with `Lich.(settingname)' exactly as though it were a variable.  So for example, `Lich.lootsack' in a script would be replaced with whatever you put here.  Note that as of v3.26+, you can make up any setting you want and just stick it in this file; once you reload the settings (see the `;help' menu or use settings.lic), it'll work like any of the previously available ones (e.g., `Lich.i_am_weirdly_named' would work if you put `i_am_weirdly_named: stuff' in here).  These really aren't very convenient; the primary reason they exist is so that Wizard scripts that try to use the standard Wizard script variables can still be run properly by Lich, and also so that when you're writing a script that you think may be of use to others you have a way of making sure it will work for anybody who properly sets their Lich settings instead of only working if they manually change the script.\r\nlootsack:\r\nboxsack:\r\nscrollsack:\r\nwandsack:\r\nsheath:\r\ngemsack:\r\npuregemsack:\r\nherbsack:\r\nmagicsack:\r\nshield:\r\nweapon:\r\nuser0:\r\nuser1:\r\nuser2:\r\nuser3:\r\nuser4:\r\nuser5:\r\nuser6:\r\nuser7:\r\nuser8:\r\nuser9:\r\ntreasure:\r\nexcludeloot:\r\n]
			file.close
			retry
		rescue SyntaxError
			$stderr.puts($!)
		rescue
			$stderr.puts($!)
			$stderr.puts($!.backtrace)
		ensure
			file ? file.close : nil
		end
	end
	def Lich.method_missing(arg1, arg2='')
		instance_eval("@@#{arg1}#{arg2}", if Script.self then Script.self.name else "Lich" end)
	end
	def Lich.fetchloot
		if items = checkloot.find_all { |item| item =~ /#{@@treasure.join('|')}/ }
			take(items)
		else
			return false
		end
	end
end

class Status
	@@head = -2..-1
	@@neck = -4..-3
	@@rarm = -6..-5
	@@larm = -8..-7
	@@rleg = -10..-9
	@@lleg = -12..-11
	@@rhand = -14..-13
	@@lhand = -16..-15
	@@chest = -18..-17
	@@abs = -20..-19
	@@back = -22..-21
	@@reye = -24..-23
	@@leye = -26..-25
	@@nerves = -28..-27
	SFMAP = Hash[ 'nsys', 'nerves', 'leftArm', 'larm', 'rightArm', 'rarm', 'rightLeg', 'rleg', 'leftLeg', 'lleg',
		'rightHand', 'rhand', 'leftHand', 'lhand', 'rightEye', 'reye', 'leftEye', 'leye', 'abdomen', 'abs',
	]
	def Status.method_missing(arg)
		arg = arg.to_s
		arg =~ /scar/ ? tag = "GSb" : tag = "GSa"
		instance_eval("dec2bin($_TAGHASH_[tag].to_i).to_s[@@#{arg.slice(/head|neck|rarm|larm|rleg|lleg|rhand|lhand|chest|abs|back|reye|leye|nerves/)}]",
			if Script.self then Script.self.name else "Lich" end)
	end
	def Status.rank(val)
		bin2dec(val.to_i)
	end
	def Status.sf_update(area, rank)
		range = Status.class_eval(sprintf("@@%s", SFMAP.fetch(area) { |query| query }))
		if rank =~ /Injury/i
			tag = [ 'GSa' ]
		elsif rank =~ /Scar/i
			tag = [ 'GSb' ]
		else
			tag = [ 'GSa', 'GSb' ]
		end
		tag.each { |t|
			buf = sprintf("%028b", $_TAGHASH_[t].to_i)
			buf[range] = dec2bin(rank.slice(/\d/).to_i).to_s[-2..-1]
			$_TAGHASH_[t] = sprintf("%010d", sprintf("0b0%s", buf))
		}
	end
end

class Wounds
	def Wounds.method_missing(arg)
		bin2dec(Status.send("woundshift#{arg}").to_i)
	end
	def Wounds.arms
		[Wounds.larm,Wounds.rarm,Wounds.lhand,Wounds.rhand].max
	end
	def Wounds.limbs
		[Wounds.larm,Wounds.rarm,Wounds.lhand,Wounds.rhand,Wounds.rleg,Wounds.lleg].max
	end
	def Wounds.torso
		[Wounds.reye,Wounds.leye,Wounds.chest,Wounds.abs,Wounds.back].max
	end
end

class Scars
	def Scars.method_missing(arg)
		bin2dec(Status.send("scarshift#{arg}").to_i)
	end
	def Scars.arms
		[Scars.larm,Scars.rarm,Scars.lhand,Scars.rhand].max
	end
	def Scars.limbs
		[Scars.larm,Scars.rarm,Scars.lhand,Scars.rhand,Scars.lleg,Scars.rleg].max
	end
	def Scars.torso
		[Scars.reye,Scars.leye,Scars.chest,Scars.abs,Scars.back].max
	end
end
class Watchfor
	def Watchfor.method_missing(*args)
		nil
	end
end

class Array
	def method_missing(*usersave)
		self
	end
end

class NilClass
	def split(*val)
		Array.new
	end
	def to_s
		""
	end
	def strip
		""
	end
end

class FalseClass
	def method_missing(*usersave)
		nil
	end
end

class String
	def method_missing(*usersave)
		""
	end
	def silent
		false
	end
	def to_s
		self.dup
	end
end

class TrueClass
	def method_missing(*usersave)
		true
	end
end

class Script
	@@wizard_save_last ||= String.new
	@@Watchfors ||= Array.new
	@@wizard_save ||= Hash.new
	at_exit { Script.shutdown_reap }
	@@wizard_cmds ||= Hash.new
	attr_accessor :opts
=begin
	@@finalizer_proc = proc { |script|
		if $LICH_DEBUG
			respond("#{$DEBUG_MESSAGE || "--- Debug: "}`#{script.to_s}' (object_id: #{script.object_id}) is being garbage collected.")
		end
	}
=end
	def wizard_cmds_init
		undef :wizard_cmds_init
		@@wizard_cmds['counter'] ||= <<-'COUNTER'
			if @lines[@stackptr] =~ /add/i
				if (csub = @lines[@stackptr].slice(/-?\d+/).to_i).nonzero?
					@wizard_counter += csub
				else
					@wizard_counter += 1
				end
			elsif @lines[@stackptr] =~ /subtract|sub/i
				if (csub = @lines[@stackptr].slice(/-?\d+/).to_i).nonzero?
					@wizard_counter -= csub
				else
					@wizard_counter -= 1
				end
			elsif @lines[@stackptr] =~ /divide/i
				@wizard_counter = (@wizard_counter / @lines[@stackptr].split.last.chomp.to_i).truncate
			elsif @lines[@stackptr] =~ /multiply/i
				@wizard_counter = (@wizard_counter * @lines[@stackptr].split.last.chomp.to_i).truncate
			elsif @lines[@stackptr] =~ /set/i
				@wizard_counter = @lines[@stackptr].split.last.chomp.to_i
			end
		COUNTER
		@@wizard_cmds['echo'] ||= <<-'ECHO'
			respond(@lines[@stackptr].sub(/echo\s?/i, '').strip)
		ECHO
		@@wizard_cmds['save'] ||= <<-'SAVE'
				@wizard_save = @lines[@stackptr].sub(/save /i, '').gsub('"','').gsub('_',"\s").strip
			@@wizard_save[@name.to_s] = @wizard_save.dup; @@wizard_save_last = @wizard_save.dup
		SAVE
		@@wizard_cmds['put'] ||= <<-'PUT'
			if @lines[@stackptr] =~ /^\s*put\s+\.([^\s]+)(\s.+)?/i
				if start_wizard_script($1.dup,$2.split)
					name = $1
					wait_until { Script.find(name) }
					exit
				end
			else
				waitrt?
				fput("#{@lines[@stackptr].sub(/put /i, '').strip}")
			end
		PUT
		@@wizard_cmds['pause'] ||= <<-'PAUSE'
			if @lines[@stackptr].split[1].to_f <= 0
				ptime = 1
			else
				ptime = @lines[@stackptr].split[1].to_f
			end
			sleep(ptime)
			waitrt?
		PAUSE
		@@wizard_cmds['goto'] ||= <<-'GOTO'
			target = @lines[@stackptr].split[1]
			target.delete!(":")
			if (found_label = @labels[target]).nil?
				if (found_label = @labels[@labels.keys.find { |val| val =~ /\b#{target}\b/i }]).nil?
					if (found_label = @labels[@labels.keys.find { |val| val =~ /labelerror/i }]).nil?
						echo("Fatal label error; '#{target}' not found, labelerror not found.")
						exit
					end
					sleep 0.02
				end
			end
			File.open($lich_dir + "lich_debug.txt", "a") { |f| f.puts "JUMP:%04s:%04s" % [ @stackptr, found_label ] } if $WIZARD_DEBUG
			@stackptr = found_label
		GOTO
		@@wizard_cmds['waitforre'] ||= <<-'WAITFORRE'
			regexp = eval(@lines[@stackptr].sub(/waitforre /i,'').strip); waitforre(regexp)
		WAITFORRE
		@@wizard_cmds['waitfor'] ||= <<-'WAITFOR'
			waitfor(Regexp.escape(@lines[@stackptr].sub(/waitfor /i, '').strip))
		WAITFOR
		@@wizard_cmds['wait'] ||= <<-'WAIT'
			clear
			get
		WAIT
		@@wizard_cmds['setvariable'] ||= <<-'SETVARIABLE'
			@setvars[@lines[@stackptr].split[1]] = @lines[@stackptr].sub(/^\s*setvariable\s+[^\s]+/i,'').strip
		SETVARIABLE
		@@wizard_cmds['deletevariable'] ||= <<-'DELETEVARIABLE'
			@setvars[@lines[@stackptr].split[1]] = String.new
		DELETEVARIABLE
		@@wizard_cmds['matchre'] ||= @@wizard_cmds['match'] ||= <<-'MATCH'
			@match_table_labels.push(@lines[@stackptr].split[1].strip)
			if @lines[@stackptr] =~ /\bmatch\b/i
				@match_table_strings.push(Regexp.escape(@lines[@stackptr].sub(/\s*match #{@match_table_labels.last} /i, '')))
			else
				@match_table_strings.push(@lines[@stackptr].sub(/\s*matchre #{@match_table_labels.last} /i, '').sub(/\/i$/,'').gsub('/',''))
			end
		MATCH
		@@wizard_cmds['matchwait'] ||= <<-'MATCHWAIT'
			the_match = waitfor(@match_table_strings.join('|'))
			idx = @match_table_strings.index(@match_table_strings.find { |val| the_match =~ /#{val}/i })
			if (found_label = @labels[@match_table_labels[idx]]).nil?
				found_label = @labels[@labels.keys.find { |lbl| lbl =~ /\b#{@match_table_labels[idx]}\b/i }]
				if found_label.nil?
					if (found_label = @labels[@labels.keys.find { |lbl| lbl =~ /labelerror/i }]).nil?
						echo("Fatal label error; '#{@match_table_labels[idx]}' not found, labelerror not found.")
						exit
					end
				end
			end
			@stackptr = found_label
			@match_table_labels.clear
			@match_table_strings.clear
		MATCHWAIT
		@@wizard_cmds['move'] ||= <<-'MOVE'
			if @rev == true
				dir = @lines[@stackptr].sub(/move /i, '').strip
				if dir =~ /\bu\b|\bup\b/i then move("down")
				elsif dir =~ /\bd\b|\bdown\b/i then move("up")
				elsif dir =~ /\bn\b|\bnorth\b/i then move("south")
				elsif dir =~ /\bne\b|\bnortheast\b/i then move("southwest")
				elsif dir =~ /\be\b|\beast\b/i then move("west")
				elsif dir =~ /\bse\b|\bsoutheast\b/i then move("northwest")
				elsif dir =~ /\bs\b|\bsouth\b/i then move("north")
				elsif dir =~ /\bsw\b|\bsouthwest\b/i then move("northeast")
				elsif dir =~ /\bw\b|\bwest\b/i then move("east")
				elsif dir =~ /\bnw\b|\bnorthwest\b/i then move("southeast")
				else move("#{dir}")
				end
			else
				move("#{@lines[@stackptr].sub(/move /i, '').strip}")
			end
		MOVE
		@@wizard_cmds['exit'] ||= <<-'EXIT'
			exit unless @rev == true
		EXIT
		@@wizard_cmds['shift'] ||= <<-'SHIFT'
			@vars.shift
		SHIFT
		@@wizard_cmds['nextroom'] ||= <<-'NEXTROOM'
			roomcount = $room_count
			waitfor('\[[^\]]+\]') while roomcount == $room_count
		NEXTROOM
	end
	private :wizard_cmds_init
	def Script.namescript_incoming_stable(string)
		@@names.each { |script| script.io.push(string) }
		@@wakeme.each { |thr|
			begin
				thr.wakeup
			rescue
#				@@wakeme.delete(thr)
			end
		}
		nil
	end
	def Script.shutdown_reap
		if Script.self
			echo "Uh, this script is trying to shut Lich down (it's tried to execute the `cleanup' method Lich uses just before it quits).  This is really of no use to scripts: the method call is being ignored."
			sleep 1
			return nil
		end
		Script.index.each { |script| script.kill }
		Thread.list.each { |thr|
			begin
				thr.join(2) if (thr.alive? and thr != Thread.current and thr != Thread.main)
			rescue
			end
		}
		nil
	end
	def Script.wrap_script(fname, iname, cmdline)
		Thread.new {
			script = Script.new(fname)
			catch(:reap) {
			begin
				pipe = IO.popen("\"#{iname}\" \"#{$script_dir + fname}\" #{cmdline}", "w+")
				pipe.sync = true
				script.instance_variable_set(:@pipe, pipe)
			rescue SystemCallError
				respond("--- Lich: #{$!}")
				throw :reap
			rescue Exception
				respond("--- Lich: #{$!}")
				throw :reap
			rescue
				respond("--- Lich: #{$!}")
				throw :reap
			end
			script.set_as_good
			script.instance_variable_get(:@dying_procs).push proc { pipe.close unless pipe.closed? }
			while line = pipe.gets
				if line =~ /^LICH:/
					begin
						if resp = eval(line.sub(/[^:]+:\s*/, ''), nil, script.name)
							pipe.puts resp
						end
					rescue SyntaxError
						respond("--- Lich: #{$!}")
						throw :reap
					rescue
						respond("--- Lich: #{$!}")
						throw :reap
					end
					next
				end
				fput line
			end
			}
			pipe = script.instance_variable_get(:@pipe)
			script.instance_variable_set(:@pipe, nil)
			pipe.close unless pipe.closed?
			script.kill
			respond("--- Lich: #{script} has ended.")
		}
		true
	end
	def initialize(name,cli_vars=[])
#		ObjectSpace.define_finalizer(self, &@@finalizer_proc)
		@thread = Thread.current
		@threads = ThreadGroup.new
		@threads.add(Thread.current)
		if cli_vars.first =~ /^quiet$/i
			@quiet = @quiet_exit = true
			cli_vars.shift
		else 
			@quiet = @quiet_exit = false
		end
		@safe = false
		if name == 'exec'
			@num = '1'
			while @@index.find { |script| script.name == "exec%s" % @num }
				@num.succ!
			end
			@name = "exec#{@num}"
		else
			@name = name
			@keysig = "#{@name}#{self.object_id.abs}"
			@labels = Hash.new
			@vars = Array.new
			unless cli_vars.empty?
				cli_vars.each_index { |idx|
					@vars[idx+1] = cli_vars[idx]
				}
				@vars[0] = @vars[1..-1].join(' ')
			end
		end
		@wizard = false
		@io = []
		@unique_io = []
		@upstream_io = []
		@opts = []
	end
	def init_wizard_script(name)
		@name = name.dup
		@keysig = "#{@name}#{self.object_id.abs}"
		@setvars = Hash.new
		@labels = Hash.new
		@stackptr = 0
		@wizard = true
		@wizard_counter = 0
		@wizard_save = @@wizard_save[@name.to_s]
		@wizard_save = @@wizard_save_last if @wizard_save.nil?
		@match_table_labels = Array.new
		@match_table_strings = Array.new
		true
	end
	def load_wizard_lines(file,rev=false)
		begin
			line = ""
			begin
				gzfile = Zlib::GzipReader.open(file)
				File.open("uncompress.cmd", "w") { |f| f.write gzfile.read }
				gzfile.close
				file = "uncompress.cmd"
			rescue
			end
			file = File.open(file)
			wizard_parse_file(file)
			file.close
			File.unlink "uncompress.cmd" if File.exists? "uncompress.cmd"
			file = nil
		rescue
			respond("--- Lich: fatal error opening file: #{file}")
		  	return false
		ensure
			file.close unless !file or file.closed? 
		end
		if rev == true
			@rev = true
			@lines.reverse!
			@lines.each_index { |idx| if @lines[idx] =~ /^[0-9A-z_]+:$/ then @labels[@lines[idx].chop] = idx end }
		else
			@rev = false
		end
		true
	end
	def process_next_wizard_line(script=nil)
		while @paused
			@sleeplist.push(Thread.current)
			sleep
			@sleeplist.delete(Thread.current)
		end
		return nil if @lines[@stackptr].nil?
		@real_line = @lines[@stackptr].dup
		@real_ptr = @stackptr
		if @lines[@stackptr] =~ /\%user([0-9])(?:\%)?/i then @lines[@stackptr].gsub!(/\%user[0-9](?:\%)?/i, Lich.user($1)) end
		@lines[@stackptr] = @lines[@stackptr].gsub(/\%container(?:\%)?/i, "#{Lich.lootsack}").gsub(/\%c(?:\%)?/i, @wizard_counter.to_s.strip).gsub(/%s(?:\%)?/i, @wizard_save.to_s.strip)
		while @lines[@stackptr] =~ /\bif\_(\d)\b/i
			if @vars[$1.to_i].nil?
				@lines[@stackptr] = ""
			else
				@lines[@stackptr] = @lines[@stackptr].sub(/\bif\_\d\b/i, "")
			end
		end
		if @lines[@stackptr] =~ /\%0(?:\%)?/
			@lines[@stackptr] = @lines[@stackptr].sub(/\%0(?:\%)?/,@vars[1..-1].join(' ').gsub('_',"\s"))
		end
		while @lines[@stackptr] =~ /\%([1-9])(?:\%)?/
			@lines[@stackptr] = @lines[@stackptr].sub(/\%[1-9](?:\%)?/, @vars[$1.to_i].to_s)
		end
		while @lines[@stackptr] =~ /\%(#{@setvars.keys.join('|')})\%?/i
			repvar = $1.dup
			@lines[@stackptr] = @lines[@stackptr].sub(/\%#{$1}\%?/,@setvars[repvar])
		end
		wizcmd = @lines[@stackptr].slice(/[^\s]+/).downcase
		wizard_cmds_init rescue()
		if wizprc = @@wizard_cmds[wizcmd]
			eval(wizprc, nil, Script.self.name, @stackptr)
		elsif @lines[@stackptr] =~ /^LICH\s*\{/
			lichcode = Array.new; lichcode.push('$SAFE = 3')
			line = @lines[@stackptr]
			until line =~ /^\}\s*LICH/
				@stackptr += 1; break if @lines[@stackptr].nil?
				lichcode.push(@lines[@stackptr])
				line = @lines[@stackptr]
			end
			eval(lichcode[0..-2].join("\n"), nil, Script.self.name, 0)
		end
		@lines[@real_ptr] = @real_line
		@stackptr += 1
		true
	end
	def setup_labels(filename,run_safe = false)
		begin
			crit = Thread.critical
			Thread.critical = true
			begin
				file = nil
				file = Zlib::GzipReader.open(filename)
			rescue
				file.close rescue()
				file = File.open(filename)
			end
			if file.gets =~ /^[\t\s]*#?[\t\s]*(?:quiet|hush)\r?$/i
				@quiet = @quiet_exit = true
			end
			file.rewind
			ary = file.read.split(/\r?\n([\d_\w]+):\s*\r?\n/)
		ensure	
			file.close
			file = nil
			Thread.critical = crit
		end
		@labels,@label_order,@line_no,line = Hash.new,Hash.new,Hash.new,String.new
		@current_label = @jump_label = @keysig
		@labels[@current_label] = String.new
		@labels[@current_label] = "script.set_as_good" + (run_safe ? "\n$SAFE = 3\necho 'This script is being run in SAFE mode'\nsleep 0.5\n" : "\n")
		@line_no[@current_label] = 0
		@labels[@current_label] += ary.shift
		data = false
		while line = ary.shift
			if data
				@labels[@current_label] = line
				data = false
			else
				line_no += @labels[@current_label].count("\n")
				@label_order[@current_label] = line
				@current_label = line
				@line_no[@current_label] = line_no
				data = true
			end
		end
		true
	end
	def fetch_next_label
		if !@jump_label
			@current_label = @label_order[@current_label]
			@current_label.nil? ? nil : @labels[@current_label]
		else
			if lbl = @labels.keys.find { |val| val =~ /^#{@jump_label}$/ } then @current_label = lbl
			elsif lbl = @labels.keys.find { |val| val =~ /^#{@jump_label}$/i } then @current_label = lbl
			elsif lbl = @labels.keys.find { |val| val =~ /^labelerror$/i } then @current_label = lbl
			else @current_label = nil; return JUMP_ERROR
			end
			@jump_label = nil
			sleep 0.001
			@labels[@current_label]
		end
	end
	def set_as_good
		@timestamp = Time.now
		@upstream = false
		@stand_alone = false
		@sleeplist = Array.new
		@pause_pushback = Array.new
		@dying_procs = Array.new
		@die_with = Array.new
		@match_stack_labels = Array.new
		@match_stack_strings = Array.new
		@paused = false
		@no_ka = false
		@status = false
		@unique = false
		@silent = false
		@no_echo = false
		@no_pause = false
		@@thread_hash[Thread.current.group] = self
		@@index.push self
		@@names.push self
		setpriority(-10) if @wizard
		respond("--- Lich: #{@name} active.") unless @quiet
	end
	def i_stand_alone
		@@names.delete(self)
		@@status_scripts.delete(self)
		@@uniques.delete(self)
		@@upstream_index.delete(self)
		self.clear
		@stand_alone = true
		echo("Script has removed itself from Lich's data queues and is functioning independently")
	end
	def take_me_back
		@@names.push(self)
		@stand_alone = false
		echo("Script is no longer functioning independently and is receiving data as normal")
	end
	def toggle_upstream
		if @upstream
			@upstream = false
			@@upstream_index.delete(self)
			@@names.push(self) unless @@names.include?(self)
		else
			@upstream = true
			@@upstream_index.push(self) unless @@upstream_index.include?(self)
			@@names.delete(self)
		end
		echo("Listening to upstream (from local computer to remote server) data is now: #{@upstream.to_s.sub('false', 'off').sub('true', 'on')}")
	end
	def feedme_upstream
		if @upstream
			@upstream = false
			@@upstream_index.delete(self)
		else
			@upstream = true
			@@upstream_index.push(self) unless @@upstream_index.include?(self)
		end
	end
	def kill
		@name.sub!(/ \(paused\)$/,'')
		kill_thread = Thread.current
		cleanup_thread = Thread.new {
			@threads.add(Thread.current)
			@paused = false
			$SAFE = 3 if @safe
			dying_procs_thread = Thread.new {
				@dying_procs.each { |runme|
					begin
						runme.call
					rescue SyntaxError
						echo("Syntax error in dying code block: #{$!}")
					rescue SystemExit
						nil
					rescue Exception
						if $! == JUMP or $! == JUMP_ERROR
							echo("Cannot execute jumps in before_dying code blocks...!")
						else
							echo("Fatal error in dying code block: #{$!}")
						end
					rescue
						echo("Fatal error in dying code block: #{$!}")
					end
				}
			}
			dying_procs_thread.join(2) if dying_procs_thread.alive? and !(@dying_procs.nil? or @dying_procs.empty?)
			dying_procs_thread.kill if dying_procs_thread.alive?
			@dying_procs.clear
			@dying_procs = nil
			@threads.list.each { |thr|
				@@wakeme.delete(thr)
				@@wakeme_status.delete(thr)
				@@wakeme_uniques.delete(thr)
				@@wakeme_upstream.delete(thr)
				@@thread_hash.delete(thr.group)
			}
			@sleeplist.clear
			@sleeplist = nil
			@data.clear; @labels.clear; @lines.clear; @label_order.clear; @match_table_labels.clear; @match_table_strings.clear
			@io.clear; @unique_io.clear; @upstream_io.clear; @match_stack_labels.clear; @match_stack_strings.clear
			@data, @labels, @lines, @label_order, @match_table_labels, @match_table_strings = nil, nil, nil, nil, nil, nil
			@io, @unique_io, @upstream_io, @match_stack_labels, @match_stack_strings, @jump_label, @current_label = nil,nil,nil,nil,nil,nil,nil
			@pause_pushback.clear; @pause_pushback = nil
			@@index.delete(self)
			@@names.delete(self)
			@@status_scripts.delete(self)
			@@uniques.delete(self)
			@@upstream_index.delete(self)
			@threads.list.each { |thr|
				if thr != Thread.current and thr != kill_thread and thr.alive?
					thr.kill rescue()
				end
			}
			GC.start
		}
		@die_with.each { |killit|
			todie = Script.find(killit)
			todie.kill unless todie == Script.self
		}
		@die_with.clear
		@die_with = nil
		@name
	end
	def toggle_unique
		if @unique
			@@uniques.delete(self)
			@@names.push(self)
			@unique = false
			echo("This script is now receiving game data in the normal fashion")
		else
			@@names.delete(self)
			@@uniques.push(self)
			@unique = true
			echo("This script will now only see data sent to it specifically")
		end
	end
	def unique?
		@unique
	end
	def toggle_no_ka
		@no_ka = !@no_ka
	end
	def toggle_pausable
		@no_pause = !@no_pause
	end
	def help?
		self.vars.qfind(/\bhelp\b/) or self.vars.empty? ? true : false
	end
	def to_s
		@name
	end
	def pause
		if @paused
			respond("--- Lich: #{@name.sub(' (paused)', '')} is already paused.")
		else	
			@paused = true
			respond("--- Lich: #{@name} paused.")
			@name = "#{@name} (paused)"
		end
	end
	def unpause
		if !@paused
			respond "--- Lich: but #{@name} isn't paused!"
			return
		end
		@name.sub!(/ \(paused\)$/,'')
		respond("--- Lich: #{@name} unpaused.")
		@paused = false
		@sleeplist.each { |sleeping|
			begin
				sleeping.wakeup if sleeping.alive?
			rescue
				respond("--- Lich: error while unpausing #{self}: #{$!.strip}.") if $LICH_DEBUG
			end
		}
		true
	end
	def Script.find(f_name=nil)
		if f_name.nil?
			Script.self
		else
			script = @@index.find { |scr| scr.name == f_name.to_s } ||
				@@index.find { |scr| scr.name =~ /^#{f_name.to_s}$/i } ||
				@@index.find { |scr| scr.name =~ /^#{f_name.to_s}/i }
			Script.self
			script
		end
	end
	def Script.wakelist
		(@@wakeme + @@wakeme_upstream +
		@@wakeme_uniques + @@wakeme_status).collect { |thr|
			@@thread_hash[thr.group]
		}.uniq
	end
	def match_stack_add(label,string)
		@match_stack_labels.push(label)
		@match_stack_strings.push(string)
	end
	def match_stack_clear
		@match_stack_labels.clear
		@match_stack_strings.clear
	end
end

class Opt
	attr_accessor :block, :help, :names, :params
	def initialize(names, params = 0, help = nil, &block)
		@help, @params, @block = help, params, block
		@names = names.to_a.flatten.collect { |val| val.strip }
	end
	def call(*args)
		@block.call(args)
	end
	def Opt.opt(*args, &block)
		obj = new(*args)
		obj.block = block
		Script.self.opts.push obj
	end
	def Opt.on(*args, &block)
		Opt.opt(*args, &block)
	end
	def Opt.add_help
		script = Script.self
		if !script.opts.find { |opt| opt.names.find { |op| op =~ /^h(?:elp)?$/i } }
			Opt.opt(["help", "h"]) {
				echo
				respond "Usage: #{$clean_lich_char}#{Script.self} [option]."
				echo
				respond "Options are:"
				Script.self.opts.each { |op|
					echo
					respond "  #{op.names.join(', ')}"
					respond "\t#{op.help}"
				}
				exit
			}
		end
	end
	def Opt.parse(ary = Script.self.vars)
		Opt.add_help
		script = Script.self
		script.vars[1..-1].each { |uservar|
			if opt_provided = script.opts.find { |op| op.names.find { |nm| nm =~ /\b#{uservar}\b/i } }
				idx = script.vars.index(uservar)
				argary = []
				argary.push script.vars.delete_at(idx)
				opt_provided.params.times { argary.push script.vars.delete_at(idx) }
				argary.compact!
				opt_provided.call(*argary)
			end
		}
	end
end

#
# Most of the methods defined hereafter are designed for use exclusively by scripts. When you tell a Lich script to 'fetchloot', what it's really doing is finding that method somewhere in the following code blocks and executing whatever that one tells it to.
#

def debug(*args)
	if $LICH_DEBUG
		if block_given?
			yield(*args)
		else
			echo(*args)
		end
	end
end

def timetest(*contestants)
	contestants.collect { |code| start = Time.now; 5000.times { code.call }; Time.now - start }
end

def goto(label)
	script = Script.self
	script.jump_label = label.to_s
	$! = JUMP
	raise $!
end

def dec2bin(n)
	"0" + [n].pack("N").unpack("B32")[0].sub(/^0+(?=\d)/, '')
end

def bin2dec(n)
	[("0"*32+n.to_s)[-32..-1]].pack("B32").unpack("N")[0]
end

def parse_list(string)
	string.split_as_list
end

def idle?(time = 60)
	Time.now - $_IDLETIMESTAMP_ >= time
end

def selectput(string, success, failure, timeout = nil)
	timeout = timeout.to_f if timeout and !timeout.kind_of?(Numeric)
	success = success.to_a if success.kind_of? String
	failure = failure.to_a if failure.kind_of? String
	raise ArgumentError, "usage is: selectput(game_command,success_array,failure_array[,timeout_in_secs])" if
		!string.kind_of?(String) or !success.kind_of?(Array) or
		!failure.kind_of?(Array) or timeout && !timeout.kind_of?(Numeric)

	success.flatten!
	failure.flatten!
	regex = /#{(success + failure).join('|')}/i
	successre = /#{success.join('|')}/i
	failurere = /#{failure.join('|')}/i
	thr = Thread.current

	timethr = Thread.new {
		timeout -= sleep(0.1) until timeout <= 0
		thr.raise(StandardError)
	} if timeout

	begin
		loop {
			fput(string)
			response = waitforre(regex)
			if successre.match(response.to_s)
				timethr.kill if timethr.alive?
				break(response.string)
			end
			yield(response.string) if block_given?
		}
	rescue
		nil
	end
end

def maxhealth
	$_TAGHASH_['MGSX'].to_i or 0
end

def maxmana
	$_TAGHASH_['MGSZ'].to_i or 0
end

def maxspirit
	$_TAGHASH_['MGSY'].to_i or 0
end

def toggle_unique
	Script.self.toggle_unique
end

def no_kill_all
	Script.self.toggle_no_ka
end

def die_with_me(*vals)
	unless scr = Script.self
		respond("In 'die_with_me' -- cannot identify calling script! Killing thread")
		Thread.current.kill
	end
	scr.die_with.push vals
	scr.die_with.flatten!
	echo("The following script(s) will now die when I do: #{scr.die_with.join(', ')}") unless scr.die_with.empty?
end

def silence_me
	unless scr = Script.self
		respond "Cannot identify what script is calling the `silence_me' method; killing this unrecognizable thread."
		Thread.current.kill
	end
	if scr.safe? then echo("WARNING: 'safe' script attempted to silence itself.  Ignoring the request.")
		sleep 1
		return true
	end
	scr.silent = !scr.silent
end

def upstream_get
	port = Script.self
	unless port.upstream then echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)") ; return false end
	port.upstream_gets
end

def upstream_waitfor(*strings)
	strings.flatten!
	port = Script.self
	unless port.upstream then echo("This script wants to listen to the upstream, but it isn't set as receiving the upstream! This will cause a permanent hang, aborting (ask for the upstream with 'toggle_upstream' in the script)") ; return false end
	regexpstr = strings.join('|')
	while line = port.upstream_gets
		if line =~ /#{regexpstr}/i
			return line
		end
	end
end

def toggle_upstream
	unless script = Script.self
		respond "Unable to identify the script attempting to toggle upstream data!  Cannot comply with call; killing this unrecognized thread."
		Thread.current.kill
	end
	script.toggle_upstream
end

def toggle_status
	unless script = Script.self
		respond "Unable to identify the script attempting to enable status-tag data!  Cannot comply with call; killing this unrecognized thread."
		Thread.current.kill
	end
	script.toggle_status
end

def checkpoison
	if $_TAGHASH_['GSJ'].nil? then return false end
	p_per = $_TAGHASH_['GSJ'].to_s[-15..-13].to_i
	p_dis = $_TAGHASH_['GSJ'].to_s[-3..-1].to_i
	if p_per.zero? then return false end
	return [p_per,p_dis]
end

def checkdisease
	if $_TAGHASH_['GSK'].nil? then return false end
	d_per = $_TAGHASH_['GSK'].to_s[-15..-13].to_i
	d_dis = $_TAGHASH_['GSK'].to_s[-3..-1].to_i
	if d_per.zero? then return false end
	return [d_per,d_dis]
end

def survivepoison?
	if checkpoison
		rate,dissipation = checkpoison
	else
		return true
	end
	health = checkhealth
	n = 0
	until rate <= 0
		health -= rate
		rate -= dissipation
		n += 1
		if health <= 0 then return false end
	end
	true
end

def before_dying(&code)
	unless script = Script.self
		respond "Unable to identify the script that's attempting to register a before_dying code block -- cannot comply with call!"
		Thread.current.kill
	end
	if code.nil?
		echo "No code block was given to the `before_dying' command!  (a \"code block\" is the stuff inside squiggly-brackets); cannot register a block of code to run when this script dies unless it provides the code block."
		sleep 1
		return nil
	end
	script.dying_procs.push(code)
	true
end

def undo_before_dying
	unless script = Script.self
		respond "Unable to identify the script that's attempting to clear its before_dying code blocks!"
		Thread.current.kill
	end
	script.dying_procs.clear
	nil
end

def abort!
	if script = Script.index.find { |scr| scr.threads == Thread.current.group }
		script.dying_procs.clear
		exit
	else
		respond "--- Lich: a script that is not being properly tracked has requested that it be `abort!'ed.  This shouldn't happen; please email the Lich `;log' dump to GS4Lich@yahoo.com so that I can track down the possible cause for this.  Killing this (unknown) script thread..."
		Thread.current.kill
	end
end

def survivedisease?
	if checkdisease
		rate,dissipation = checkdisease
	else
		return true
	end
	health = checkhealth
	n = 0
	deadat = 0
	until rate <= 0
		health -= rate
		rate -= dissipation
		n += 1
		if health <= 0 then return false end
	end
	true
end

def send_to_script(*values)
	values.flatten!
	if scr = Script.index.find { |val| val.name =~ /^#{values.first}/i }
		values[1..-1].each { |val| scr.puts(val) }
		echo("Sent to #{scr} -- '#{values[1..-1].join(' ; ')}'")
		return true
	else
		echo("'#{values.first}' does not match any active scripts!")
		return false
	end
end

def unique_send_to_script(*values)
	values.flatten!
	if scr = Script.index.find { |val| val.name =~ /^#{values.first}/i }
		values[1..-1].each { |val| scr.unique_puts(val) }
		echo("sent to #{scr}: #{values[1..-1].join(' ; ')}")
		return true
	else
		echo("'#{values.first}' does not match any active scripts!")
		return false
	end
end

def unique_waitfor(*strings)
	strings.flatten!
	scr = Script.self
	regexp = /#{strings.join('|')}/
	while true
		str = scr.unique_gets
		if str =~ regexp
			return str
		end
	end
end

def unique_get
	Script.self.unique_gets
end

def send_lichnet_string(string)
	if running = Script.index.find { |script| script.name =~ /lichnet/i }
		running.unique_puts(string)
	else
		respond("You aren't running the `LichNet' client script! Type `#{$clean_lich_char}lichnet' to start it.")
	end
end

def multimove(*dirs)
	dirs.flatten.each { |dir| move(dir) }
end

def n
	'north'
end
def ne
	'northeast'
end
def e
	'east'
end
def se
	'southeast'
end
def s
	'south'
end
def sw
	'southwest'
end
def w
	'west'
end
def nw
	'northwest'
end
def u
	'up'
end
def up
	'up'
end
def down
	'down'
end
def d
	'down'
end
def o
	'out'
end
def out
	'out'
end

def move(dir="none")
	attempts = 0
	if dir == "none"
		echo("Error! Move without a direction to move in!")
		return false
	else
		roomcount = $room_count
		clear
		moveflag = true
		put("#{dir}")
		while feed = get
			if feed =~ /can't go there|Where are you trying to go|What were you referring to\?| appears to be closed\.|I could not find what you were referring to\.|You can't climb that\./
				echo("Error, can't go in the direction specified!")
				Script.self.io.unshift(feed)
				return false
			elsif feed =~ /Sorry, you may only type ahead/
				sleep(1)
				clear
				put("#{dir}")
				next
			elsif feed =~ /will have to stand up first|must be standing first/
				clear
				put("stand")
				while feed = get
					if feed =~ /struggle.+stand/
						clear
						put("stand")
						next
					elsif feed =~ /stand back up|You scoot your chair back and stand up\./
						clear
						put("#{dir}")
						break
					elsif feed =~ /\.\.\.wait /
						wait = $'.split.first.to_i
						sleep(wait)
						clear
						put("stand")
						next
					elsif feed =~ /Sorry, you may only type ahead/
						sleep(1)
						clear
						put("stand")
						next
					elsif feed =~ /can't do that while|can't seem to|don't seem|stunned/
						sleep(1)
						clear
						put("stand")
						next
					elsif feed =~ /are already standing/
						clear
						put("#{dir}")
						break
					else
						stand_attempts = 0 if stand_attempts.nil?
						if stand_attempts >= 10
							echo("Error! #{stand_attempts} unrecognized responses, assuming a script hang...")
							Script.self.io.unshift(feed)
							return false
						end
						stand_attempts += 1
						sleep(1)
						clear
						put("stand")
						next
					end
				end
			elsif feed =~ /\.\.\.wait |Wait /
				wait_time = $'.split.first.to_i
				sleep(wait_time)
				clear
				put("#{dir}")
				next
			elsif feed =~ /stunned/
				wait_while { stunned? }
				clear
				put("#{dir}")
				next
			elsif feed =~ /can't do that|can't seem to|don't seem /
				sleep(1)
				clear
				put("#{dir}")
				next
			elsif feed =~ /Please rephrase that command/
				echo("error! Cannot go '#{dir}', game did not understand the command.")
				Script.self.io.unshift(feed)
				return false
			elsif feed =~ /seems as though all the tables here are/
				sleep 1
				clear
				put("#{dir}")
				next
			elsif feed =~ /You head over to the .+ Table/
				Script.self.io.unshift(feed)
				return feed
			elsif feed =~ /Running heedlessly through the icy terrain, you slip on a patch of ice and flail uselessly as you land on your rear!/
				waitrt?
				fput('stand') unless standing?; waitrt?; fput(dir); next
			else
				if attempts >= 35
					echo("#{attempts} unrecognized lines, assuming a script hang; move command has exited.")
					Script.self.io.unshift(feed)
					return false
#				elsif $stormfront
#					if feed =~ /\[[^\]]+\]/ && feed !~ /\[.*d\s?100.*\]/i or $room_count > roomcount
#						Script.self.io.unshift(feed)
#						return feed
#					else
#						attempts += 1; next
#					end
				else
					if $room_count > roomcount
						Script.self.io.unshift(feed)
						return feed
					else
						attempts += 1; next
					end
				end
			end
		end
	end
end

def checkloot
	fput("look")
	items = Array.new
	linein = matchwait("You also see ", "You notice ", "Obvious exits:|Obvious paths:|Also here:")
	if linein =~ /Obvious (exits|paths): |Also here: / then return false end
	linein = linein.slice(/You (?:also see|notice) [^\.]+\./)
	linein.sub!(/You (?:also see|notice) /, ',')
	linein.sub('.','').sub(/ and (?:an?|some|the)/, ',').split(',').each { |full_name| items.push(full_name.slice(/[^\s]+$/)) }
	if Lich.excludeloot.empty? then (regexpstr = nil) else (regexpstr = Lich.excludeloot.join('|')) end
	items.shift
	if items.empty?
		return false
	else
		return items
	end
end

def fetchloot(userbagchoice=Lich.lootsack)
	fput("look")
	items = Array.new
	linein = matchwait("You also see ", "You notice ", "Obvious exits:|Obvious paths:|Also here:")
	if linein =~ /Obvious (?:exits|paths): |Also here: / then return false end
	linein = linein.slice(/You (?:also see|notice) [^\.]+\./)
	unless Lich.excludeloot.empty? then (regexpstr = Lich.excludeloot.join('|')) end
	linein.sub!(/You (?:also see|notice) /, ',')
	unless Lich.excludeloot.empty?
		linein.sub('.','').sub(/ and (?:an?|some|the)/, ',').split(',').each { |full_name| items.push(full_name.slice(/[^\s]+$/)) unless (full_name =~ /#{regexpstr}/) }
	else
		linein.sub('.','').sub(/ and (?:an?|some|the)/, ',').split(',').each { |full_name| items.push(full_name.slice(/[^\s]+$/)) }
	end
	items.shift
	items.delete_if { |val| val =~ /^\s*$|^\s*and\s*$/i || val.nil? }
	if items.empty?
		return false
	end
	if (righthand? && lefthand? && !$stormfront)
		weap = checkright
		fput "put my #{checkright} in my #{Lich.lootsack}"
		unsh = true
	else
		unsh = false
	end
	items.each { |trinket|
		fput "take #{trinket}"
		fput("put my #{trinket} in my #{userbagchoice}") if (righthand? || lefthand? || $stormfront)
	}
	if unsh then fput("take my #{weap} from my #{Lich.lootsack}") end
end

def no_pause_all
	script = Script.self
	script.toggle_pausable
end

def pause_script(*names)
	names.flatten!
	if names.empty?
		Script.self.pause
		Script.self
	else
		names.each { |scr|
			fnd = Script.index.find { |nm| nm.name =~ /^#{scr}/i }
			fnd.pause unless (fnd.paused || fnd.nil?)
		}
	end
end

def unpause_script(*names)
	names.flatten!
	names.each { |scr| fnd = Script.index.find { |nm| nm.name =~ /^#{scr}/i } ; fnd.unpause if (fnd.paused && !(fnd.nil?)) }
end

def i_stand_alone
	loner = Script.self
	if loner.stand_alone
		loner.take_me_back
	else
		loner.i_stand_alone
	end
	loner.stand_alone
end

def take(*items)
	items.flatten!
	if (righthand? && lefthand? && !$stormfront)
		weap = checkright
		fput "put my #{checkright} in my #{Lich.lootsack}"
		unsh = true
	else
		unsh = false
	end
	items.each { |trinket|
		fput "take #{trinket}"
		fput("put my #{trinket} in my #{Lich.lootsack}") if (righthand? || lefthand? || $stormfront)
	}
	if unsh then fput("take my #{weap} from my #{Lich.lootsack}") end
end

def watchhealth(value, theproc=nil, &block)
	value = value.to_i
	if block.nil?
		if !theproc.respond_to? :call
			respond "`watchhealth' was not given a block or a proc to execute!"
			return nil
		else
			block = theproc
		end
	end
	Thread.new {
		wait_while { health(value) }
		block.call
	}
end

def waitrt
	until $_TAGHASH_["GSQ"].to_i > $_TAGHASH_["GSq"].to_i
		sleep 0.1
	end
	if $_TAGHASH_["GSq"].to_i >= $_TAGHASH_["GSQ"].to_i then return end
	sleep(($_TAGHASH_["GSQ"].to_f - (Time.now.to_f - $_TIMEOFFSET_.to_f) + 0.6).abs)
end

def waitrt?
	if $_TAGHASH_["GSQ"].to_i > $_TAGHASH_["GSq"].to_i then waitrt end
end

def wait_until(announce=nil)
	priosave = Thread.current.priority
	Thread.current.priority = -10
	unless announce.nil? or yield
		respond(announce)
	end
	until yield
		sleep 0.25
	end
	Thread.current.priority = priosave
end

def wait_while(announce=nil)
	priosave = Thread.current.priority
	Thread.current.priority = -10
	unless announce.nil? or !yield
		respond(announce)
	end
	while yield
		sleep 0.25
	end
	Thread.current.priority = priosave
end

def checkpaths(dir="none")
	if dir == "none"
		dirs = Array.new
		$_TAGHASH_["GSj"].chomp.split('').each { |char|
			if char == "A"
				dirs.push("n")
			elsif char == "B"
				dirs.push("ne")
			elsif char == "C"
				dirs.push("e")
			elsif char == "D"
				dirs.push("se")
			elsif char == "E"
				dirs.push("s")
			elsif char == "F"
				dirs.push("sw")
			elsif char == "G"
				dirs.push("w")
			elsif char == "H"
				dirs.push("nw")
			elsif char == "I"
				dirs.push("up")
			elsif char == "J"
				dirs.push("down")
			elsif char == "K"
				dirs.push("out")
			end
		}
		if dirs.empty?
			return false
		else
			return dirs.to_a
		end
	else
		dirs = Array.new
		$_TAGHASH_["GSj"].chomp.split('').each { |char|
			if char == "A"
				dirs.push("n",n)
			elsif char == "B"
				dirs.push("ne",ne)
			elsif char == "C"
				dirs.push("e",e)
			elsif char == "D"
				dirs.push("se",se)
			elsif char == "E"
				dirs.push("s",s)
			elsif char == "F"
				dirs.push("sw",sw)
			elsif char == "G"
				dirs.push("w",w)
			elsif char == "H"
				dirs.push("nw",nw)
			elsif char == "I"
				dirs.push("up",u)
			elsif char == "J"
				dirs.push("down",d)
			elsif char == "K"
				dirs.push("out",'o')
			end
		}
		dirs.include?(dir)
	end
end

def reverse_direction(dir)
	if dir == "n" then 's'
	elsif dir == "ne" then 'sw'
	elsif dir == "e" then 'w'
	elsif dir == "se" then 'nw'
	elsif dir == "s" then 'n'
	elsif dir == "sw" then 'ne'
	elsif dir == "w" then 'e'
	elsif dir == "nw" then 'se'
	elsif dir == "up" then 'down'
	elsif dir == "down" then 'up'
	elsif dir == "out" then 'out'
	elsif dir == 'o' then out
	elsif dir == 'u' then 'down'
	elsif dir == 'd' then up
	elsif dir == n then s
	elsif dir == ne then sw
	elsif dir == e then w
	elsif dir == se then nw
	elsif dir == s then n
	elsif dir == sw then ne
	elsif dir == w then e
	elsif dir == nw then se
	elsif dir == u then d
	elsif dir == d then u
	else echo("Cannot recognize direction to properly reverse it!"); false
	end
end

def walk(*boundaries, &block)
	boundaries.flatten!
	unless block.nil?
		until val = yield
			walk(*boundaries)
		end
		return val
	end
	if $last_dir and !boundaries.empty? and checkroomdescrip =~ /#{boundaries.join('|')}/i
		move($last_dir)
		$last_dir = reverse_direction($last_dir)
		return checknpcs
	end
	dirs = checkpaths
	dirs.delete($last_dir) unless dirs.length < 2
	this_time = rand(dirs.length)
	$last_dir = reverse_direction(dirs[this_time])
	move(dirs[this_time])
	checknpcs
end

def toggle_echo(onoff="none")
	script = Script.self
	if script.no_echo then script.no_echo = false else script.no_echo = true end
end

def run
	loop { break unless walk }
end

def checkfried
	checkmind(8) or checkmind(9)
end

def checkmind(string=nil)
	chkmind = $_TAGHASH_["GSr"].chomp.strip
	if chkmind == "A"
		mind = "clear as a bell"
	elsif chkmind == "B"
		mind = "fresh and clear"
	elsif chkmind == "C"
		mind = "clear"
	elsif chkmind == "D"
		mind = "muddled"
	elsif chkmind == "E"
		mind = "becoming numbed"
	elsif chkmind == "F"
		mind = "numbed"
	elsif chkmind == "G"
		mind = "fried"
	elsif chkmind == "H"
		mind = "fried"
	else
		mind = "beyond fried"
	end
	if string.nil?
		return mind
	elsif string.class == String and string.to_i == 0
		if string =~ /#{mind}/i
			return true
		else
			return false
		end
	elsif string.to_i.between?(1,9)
		ary = %w[A B C D E F G H]
		mind = ary.index($_TAGHASH_['GSr'].strip) + 1
		return string.to_i <= mind
	else
		echo("Checkmind error! You must provide an integer ranging from 1-9 (7 is fried, 8 is 100% fried, 9 is extremely rare and is impossible through normal means to reach but does exist), the common abbreviation of how full your head is, or provide no input to have checkmind return an abbreviation of how filled your head is.") ; sleep 1
		return false
	end
end

def checkarea(*strings)
	strings.flatten! ; if strings.empty? then return $roomarea.sub('[','') end
	$roomarea =~ /#{strings.join('|')}/i
end

def checkroom(*strings)
	strings.flatten! ; if strings.empty? then return $roomtitle.chomp end
	$roomtitle =~ /#{strings.join('|')}/i
end

def outside?
	$_PATHSLINE_ =~ /Obvious paths:/
end

def checkfamarea(*strings)
	strings.flatten!
	if strings.empty? then return $familiar_area.sub('[','') end
	$familiar_area =~ /#{strings.join('|')}/i
end

def checkfampaths(dir="none")
	if dir == "none"
		dirs = Array.new
		$familiar_paths.chomp.split('').each { |char|
			if char == "A"
				dirs.push("n")
			elsif char == "B"
				dirs.push("ne")
			elsif char == "C"
				dirs.push("e")
			elsif char == "D"
				dirs.push("se")
			elsif char == "E"
				dirs.push("s")
			elsif char == "F"
				dirs.push("sw")
			elsif char == "G"
				dirs.push("w")
			elsif char == "H"
				dirs.push("nw")
			elsif char == "I"
				dirs.push("up")
			elsif char == "J"
				dirs.push("down")
			elsif char == "K"
				dirs.push("out")
			end
		}
		if dirs.empty?
			return false
		else
			return dirs.to_a
		end
	else
		dirs = Array.new
		$familiar_paths.split('').each { |char|
			if char == "A"
				dirs.push("n")
			elsif char == "B"
				dirs.push("ne")
			elsif char == "C"
				dirs.push("e")
			elsif char == "D"
				dirs.push("se")
			elsif char == "E"
				dirs.push("s")
			elsif char == "F"
				dirs.push("sw")
			elsif char == "G"
				dirs.push("w")
			elsif char == "H"
				dirs.push("nw")
			elsif char == "I"
				dirs.push("up")
			elsif char == "J"
				dirs.push("down")
			elsif char == "K"
				dirs.push("out")
			end
		}
		if dirs.find { |val| val =~ /#{dir}/i }
			return true
		else
			return false
		end
	end
end

def checkfamroom(*strings)
	strings.flatten! ; if strings.empty? then return $familiar_room.chomp end
	$familiar_room =~ /#{strings.join('|')}/i
end

def checkfamnpcs(*strings)
	parsed = Array.new
	$familiar_npcs.each { |val| parsed.push(val.split.last) }
	if strings.empty?
		if parsed.empty?
			return false
		else
			return parsed
		end
	else
		if mtch = strings.find { |lookfor| parsed.find { |critter| critter =~ /#{lookfor}/ } }
			return mtch
		else
			return false
		end
	end
end

def checksitting
	$_TAGHASH_["GSP"].include?('H') and !$_TAGHASH_["GSP"].include?('G')
end

def checkkneeling
	$_TAGHASH_["GSP"] =~ /GH/
end

def checkstunned
	$_TAGHASH_["GSP"].include?('I')
end

def checkbleeding
	$_TAGHASH_["GSP"].include?('O')
end

def checkgrouped
	$_TAGHASH_["GSP"].include?('P')
end

def checkdead
	$_TAGHASH_["GSP"].include?('B')
end

def checkreallybleeding
	checkbleeding and !$_TAGHASH_['GSP'].include?('W')
end

def muckled?
	checkwebbed or checkdead or checkstunned
end

def checkhidden
	$_TAGHASH_["GSP"].include?('N')
end

def checkwebbed
	$_TAGHASH_["GSP"].include?('C')
end

def checkprone
	$_TAGHASH_['GSP'].include?('G') and !$_TAGHASH_['GSP'].include?('H')
end

def checknotstanding
	$_TAGHASH_['GSP'].include?('H') or $_TAGHASH_['GSP'].include?('G')
end

def checkstanding
	!checknotstanding
end

def checkname(*strings)
	strings.flatten!
	if strings.empty?
		if Char.name
			Char.name
		else
			name = $_SERVERBUFFER_.find { |line| line =~ /\034GSB\d+(\w+)/ }
			if name
				$1.strip
			else
				nil
			end
		end
	else
		Char.name =~ /^(?:#{strings.join('|')})/i
	end
end

def checkfampcs(*strings)
	familiar_pcs = Array.new
	$familiar_pcs.to_s.gsub(/Lord |Lady |Great |High |Renowned |Grand |Apprentice |Novice |Journeyman /,'').split(',').each { |line| familiar_pcs.push(line.slice(/[A-Z][a-z]+/)) }
	if familiar_pcs.empty?
		return false
	elsif strings.empty?
		return familiar_pcs
	else
		regexpstr = strings.join('|\b')
		peeps = familiar_pcs.find_all { |val| val =~ /\b#{regexpstr}/i }
		if peeps.empty?
			return false
		else
			return peeps
		end
	end
end

def checkpcs(*strings)
	if $pcs.empty?
		if strings.empty? then return nil else return false end
	end
	pcs = $pcs.gsub(/Novice |Apprentice |Journeyman |Lord |Lady |Great |High |Renowned |Grand /, '').scan(/[A-Z][a-z]+/)
	strings.flatten!
	if strings.empty?
		if pcs.empty? then return nil else return pcs end
	else
		regexpstr = strings.join(' ')
		if (here = pcs.find { |pc| regexpstr =~ /\b#{pc}/i }) then return here else return false end
	end
end

def checknpcs(*string)
	if $npcs.empty?
		return nil
	elsif string.empty?
		$npcs.delete_if { |n| n =~ /[0-9]+/ }
		unless (npcs = $npcs.collect { |val| val.split.last }).empty? then return npcs.dup else return nil end
	else
		$npcs.delete_if { |n| n =~ /[0-9]+/ }
		regexpstr = string.join(' ')
		if (here = $npcs.find { |npc| regexpstr =~ /\b#{npc.split.last}/i }) then return here.dup else return false end
	end
end

def count_npcs
	checknpcs.length
end

def checkright(*hand)
	if $_TAGHASH_["GSm"].nil? then return nil end
	hand.flatten!
	if $stormfront
		right_hand = $_TAGHASH_["GSm"].strip
	else
		right_hand = $_TAGHASH_["GSm"].scan(/[^\r\n]{1,15}/).collect { |val| val.strip }.join("\s")
	end
	if right_hand == "Empty" or right_hand.empty?
		nil
	elsif hand.empty?
		right_hand.slice(/[^\s]+$/)
	else
		hand.find { |instance| right_hand =~ /#{instance}/i }
	end
end

def checkleft(*hand)
	if $_TAGHASH_["GSl"].nil? then return nil end
	hand.flatten!
	if $stormfront
		left_hand = $_TAGHASH_["GSl"].strip
	else
		left_hand = $_TAGHASH_["GSl"].scan(/[^\r\n]{1,15}/).collect { |val| val.strip }.join("\s")
	end
	if left_hand == "Empty" or left_hand.empty?
		nil
	elsif hand.empty?
		left_hand.slice(/[^\s]+$/)
	else
		hand.find { |instance| left_hand =~ /#{instance}/i }
	end
end

def percentstamina(num=nil)
	unless ($_FAKE_STORMFRONT || $stormfront) then echo("Stamina tracking is only available in StormFront! Returning...") ; sleep 1 ; return false end
	unless num.nil?
		((checkstamina.to_f / maxstamina.to_f) * 100).to_i >= num.to_i
	else
		((checkstamina.to_f / maxstamina.to_f) * 100).to_i >= num.to_i
	end
end

def percenthealth(num=nil)
	unless num.nil?
		((checkhealth.to_f / maxhealth.to_f) * 100).to_i >= num.to_i
	else
		((checkhealth.to_f / maxhealth.to_f) * 100).to_i
	end
end

def percentmana(num=nil)
	unless num.nil? then ((checkmana.to_f / maxmana.to_f) * 100).to_i >= num.to_i
	else ((checkmana.to_f / maxmana.to_f) * 100).to_i end
end

def percentspirit(num=nil)
	unless num.nil? then ((checkspirit.to_f / maxspirit.to_f) * 100).to_i >= num.to_i
	else ((checkspirit.to_f / maxspirit.to_f) * 100).to_i end
end

def checkmana(num=nil)
	if num.nil? then $_TAGHASH_['GSZ'].to_i else $_TAGHASH_['GSZ'].to_i >= num.to_i end
end

def checkroomdescrip(*val)
	val.flatten!
	if val.empty? then return $roomdescription.sub(/\034.*/,'').strip end
	$roomdescription.sub(/\034.*/,'').strip =~ /#{val.join('|')}/i
end

def checkstance(num=nil)
	if num.nil?
		checkstance = $_TAGHASH_["GSg"].to_i
		if checkstance == 00 then 'offensive'
		elsif checkstance.between?(01, 20) then 'advancing'
		elsif checkstance.between?(21, 40) then 'forward'
		elsif checkstance.between?(41, 60) then 'neutral'
		elsif checkstance.between?(61, 80) then 'guarded'
		elsif checkstance.between?(81, 100) then 'defensive'
		else 'unknown' end
	elsif (num.class == String && num.to_i == 0)
		stance = $_TAGHASH_["GSg"].to_i
		if num =~ /off/i then stance == 00
		elsif num =~ /adv/i then stance.between?(01, 20)
		elsif num =~ /for/i then stance.between?(21, 40)
		elsif num =~ /neu/i then stance.between?(41, 60)
		elsif num =~ /gua/i then stance.between?(61, 80)
		elsif num =~ /def/i then stance == 100
		else echo("Unrecognized stance! Must be off/adv/for/neu/gua/def"); nil end
	else
		echo("Script warning, checkstance was passed an argument of unknown type, assuming type integer and comparing...")
		$_TAGHASH_["GSg"].to_i == num.to_i
	end
end

def checkspell(*spells)
	spells.flatten!
	if Spell.active.empty? then return false end
	spells.each { |spell|
		unless Spell[spell].active? then return false end
	}
	true
end

def checkprep(spell=nil)
	if spell.nil? then $_TAGHASH_["GSn"].strip
	elsif spell.class != String then echo("Checkprep error, spell # not implemented!  You must use the spell name"); false
	else $_TAGHASH_['GSn'].strip =~ /^#{spell}/i end
end

def checkspirit(num=nil)
	if num.nil? then $_TAGHASH_['GSY'].to_i else $_TAGHASH_['GSY'].to_i >= num.to_i end
end

def checkhealth(num=nil)
	if num.nil? then $_TAGHASH_['GSX'].to_i else $_TAGHASH_['GSX'].to_i >= num.to_i end
end

def setpriority(val=nil)
	if val.nil? then return Thread.current.priority end
	if val.to_i > 3
		echo("You're trying to set a script's priority as being higher than the send/recv threads (this is telling Lich to run the script before it even gets data to give the script, and is useless); the limit is 3")
		return Thread.current.priority
	else
		Thread.current.group.list.each { |thr| thr.priority = val.to_i }
		return Thread.current.priority
	end
end

def checkstamina(num=nil)
	if $_TAGHASH_['stamina'].nil? then echo("Stamina tracking is only functional when you're using StormFront!"); nil elsif num.nil? then $_TAGHASH_['stamina'].to_i else $_TAGHASH_['stamina'].to_i >= num.to_i end
end

def variable
	Script.self.vars
end

def maxstamina(num=0)
	unless ($_FAKE_STORMFRONT || $stormfront) then echo("Stamina is only tracked in StormFront! Unable to continue; returning") ; sleep 1 ; return false end
	if num.zero?
		$_TAGHASH_['Mstamina'].to_i
	else
		$_TAGHASH_['Mstamina'].to_i >= num.to_i
	end
end

def pause(num=1)
	if num =~ /m/
		sleep((num.sub(/m/, '').to_f * 60))
	elsif num =~ /h/
		sleep((num.sub(/h/, '').to_f * 3600))
	elsif num =~ /d/
		sleep((num.sub(/d/, '').to_f * 86400))
	else
		sleep(num.to_f)
	end
end

def cast(spell,*targets)
	pushback_ary = []
	regex = Regexp.new(["Spell Hindrance for",
		"(?:Cast|Sing) Roundtime [0-9]+ Seconds",
		"You don't have a spell prepared\!",
		"already have a spell prepared",
		"The searing pain in your throat makes that impossible",
	].join('|'), "i")

	if !Spell[spell.to_i].nil?
		cost = eval(Spell[spell.to_i].cost)
	elsif spell == 1030
		if targets.empty?
			cost = 20
		else
			cost = 15
		end
	else
		cost = spell.to_s[-2..-1].to_i
	end
	if targets.empty?
		while mana?(cost)
			fput "incant #{spell}"
			chk = ""
			while chk !~ regex
				chk = get
				pushback_ary.push chk
			end
			unless chk =~ /spell hindrance for|The searing pain in your throat makes that impossible|don't have a spell prep/i
				sleep(3)
				Script.self.io.unshift(pushback_ary).flatten!
				return true
			end
		end
		return false
	else
		last = 0
		targets.each_with_index { |target,idx|
			while mana?(cost)
				fput "prep #{spell}"
				fput "cast at #{target}"
				chk = ""
				while chk !~ regex
					chk = get
					pushback_ary.push chk
				end
				unless chk =~ /spell hindrance for|The searing pain in your throat makes that impossible|don't have a spell prep/i
					sleep(3)
					last = idx
					break
				end
			end
		}
		Script.self.io.unshift(pushback_ary).flatten!
		if mana?(cost) and targets.length.eql?((last + 1))
			return true
		else
			return false
		end
	end
end

def clear(opt=0)
  	port = Script.self
	to_return = port.io.dup
	port.clear
	to_return
end

def matchwait(*strings)
	strings.flatten!
	unless port = Script.self
		echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...")
		Thread.current.kill
		return false
	end
	if port.unique
		echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting")
		sleep 1
		return false
	end
	unless strings.empty?
		regexpstr = strings.collect { |str| str.kind_of?(Regexp) ? str.source : str }.join('|')
		regexobj = /#{regexpstr}/
		while line_in = port.gets
			return line_in if line_in =~ regexobj
		end
	else
		strings = port.match_stack_strings
		labels = port.match_stack_labels
		regexpstr = /#{strings.join('|')}/i
		while line_in = port.gets
			if mdata = regexpstr.match(line_in)
				jmp = labels[strings.index(mdata.to_s) || strings.index(strings.find { |str| line_in =~ /#{str}/i })]
				port.match_stack_clear
				goto jmp
			end
		end
	end
end

def waitforre(regexp)
	unless regexp.class == Regexp then echo("Script error! You have given 'waitforre' something to wait for, but it isn't a Regular Expression! Use 'waitfor' if you want to wait for a string."); sleep 1; return nil end
	unless script = Script.self then echo("An unknown script thread tried to fetch a game line from the queue with the 'waitforre' command, but Lich can't process the call without knowing which script is calling! Aborting..."); Thread.current.kill; return nil end
	if script.unique then echo("WARNING: This script is set to NOT be fed any game data with the 'unique' setting and is trying to look at incoming game data! This probably isn't what you want it to do, but attempting command anyway...") end
	while true
		if regobj = regexp.match(script.gets) then return regobj end
	end
end

def waitfor(*strings)
	strings.flatten!
	unless port = Script.self then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
	if port.wizard and strings.length == 1 and strings.first.strip == '>'
		return port.gets
	end
	if strings.empty? then echo("waitfor without any strings to wait for!") ; return false end
	if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
	regexpstr = strings.join('|')
	while true
		line_in = port.gets
		if (line_in =~ /#{regexpstr}/i) then return line_in end
	end
end

def wait
	unless port = Script.self then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
	if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
	port.clear
	return port.gets
end

def get
	Script.self.gets
end

def reget(*lines)
	lines.flatten!
	if caller.find { |c| c =~ /regetall/ }
		history = ($_SERVERBUFFER_.history + $_SERVERBUFFER_)
	else
		history = $_SERVERBUFFER_.dup
	end
	unless Script.status_scripts.include?(Script.self)
		if $stormfront
			history.collect! { |line|
				line = line.strip.gsub(/<[^>]+>/, '')
				line.empty? ? nil : line
			}.compact!
		else
			history.collect! { |line|
				line = line.strip.gsub(/\034.*/, '')
				line.empty? ? nil : line
			}.compact!
		end
	end
	if lines.first.kind_of? Numeric or lines.first.to_i.nonzero?
		num = lines.shift.to_i
	else
		num = history.length
	end
	unless lines.empty?
		regex = /#{lines.join('|')}/i
		history = history[-num..-1].find_all { |line| line =~ regex }
	end
	history.empty? ? nil : history
end

def regetall(*lines)
	reget(*lines)
end

def multifput(*cmds)
	cmds.flatten.compact.each { |cmd| fput(cmd) }
end

def fput(message, *waitingfor)
	waitingfor.flatten!
	clear
	put(message)

	if Script.self.unique
		debug("(debug info) This script is set as `unique' and is not aware of what is happening in the game; as such, `fput' cannot function properly.  Executing a `put' instead.")
		return
	end

	while string = get
		if string =~ /(?:\.\.\.wait |Wait )[0-9]+/
			hold_up = string.slice(/[0-9]+/).to_i
			sleep(hold_up) unless hold_up.nil?
			clear
			put(message)
			next
		elsif string =~ /struggle.+stand/
			clear
			fput("stand")
			next
		elsif string =~ /stunned|can't do that while|cannot seem|can't seem|don't seem|Sorry, you may only type ahead/
			if dead?
				echo("You're dead...! You can't do that!")
				sleep 1
				Script.self.io.unshift(string)
				return false
			elsif checkstunned
				while checkstunned
					sleep(0.25)
				end
			elsif checkwebbed
				while checkwebbed
					sleep(0.25)
				end
			else
				sleep(1)
			end
			clear
			put(message)
			next
		else
			if waitingfor.empty?
				Script.self.io.unshift(string)
				return string
			else
				if foundit = waitingfor.find { |val| string =~ /#{val}/i } then Script.self.io.unshift(string) ; return foundit end
				sleep 1
				clear
				put(message)
				next
			end
		end
	end
end

def put(*messages)
  $TALIMIT = 0 if $TALIMIT.nil?
	messages.each { |message|
		message.chomp!
		unless scr = Script.self then scr = "(script unknown)" end
		unless $stormfront
			if message.strip.empty?
				next
			elsif $TA_waiting_on_resp >= $TALIMIT and $TALIMIT.nonzero?
				$_TA_BUFFER_.push message
				$_CLIENTBUFFER_.push("[#{scr}]#{$SEND_CHARACTER}#{message}\r\n")
				$_CLIENT_.write("(queued): [#{scr}]#{$SEND_CHARACTER}#{message}\r\n") unless scr.silent
				$_LASTUPSTREAM_ = "[#{scr}]#{$SEND_CHARACTER}#{message}"
			else
				$TA_waiting_on_resp += 1
				$_CLIENTBUFFER_.push("[#{scr}]#{$SEND_CHARACTER}#{message}\r\n")
				$_CLIENT_.write("[#{scr}]#{$SEND_CHARACTER}#{message}\r\n") unless scr.silent
				$_SERVER_.write("#{message}\n")
				$_LASTUPSTREAM_ = "[#{scr}]#{$SEND_CHARACTER}#{message}"
			end
		else
			$_CLIENTBUFFER_.push("[#{scr}]#{$SEND_CHARACTER}<c>#{message}\r\n")
			respond("[#{scr}]#{$SEND_CHARACTER}#{message}\r\n") unless scr.silent
			$_SERVER_.write("<c>#{message}\n")
			$_LASTUPSTREAM_ = "[#{scr}]#{$SEND_CHARACTER}#{message}"
		end
	}
end

def echo(*messages)
	scr = Script.self || '(unknown script)'
	messages = messages.flatten.compact
	respond if messages.empty?
	messages.each { |message| respond("[#{scr}: #{message.to_s.chomp}]") } unless scr.no_echo
	nil
end

def quiet_exit
	script = Script.self
	script.quiet_exit = !(script.quiet_exit)
end

def matchfindexact(*strings)
	strings.flatten!
  	unless port = Script.self then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
	if strings.empty? then echo("error! 'matchfind' with no strings to look for!") ; sleep 1 ; return false end
	looking = Array.new
	strings.each { |str| looking.push(str.gsub('?', '(\b.+\b)')) }
	if looking.empty? then echo("matchfind without any strings to wait for!") ; return false end
	if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
	regexpstr = looking.join('|')
	while line_in = port.gets
		if gotit = line_in.slice(/#{regexpstr}/)
			matches = Array.new
			looking.each_with_index { |str,idx|
				if gotit =~ /#{str}/i
					strings[idx].count('?').times { |n| matches.push(eval("$#{n+1}")) }
				end
			}
			break
		end
	end
	if matches.length == 1
		return matches.first
	else
		return matches.compact
	end
end

def matchfind(*strings)
	regex = /#{strings.flatten.join('|').gsub('?', '(.+)')}/i
	unless script = Script.self
		respond "Unknown script is asking to use matchfind!  Cannot process request without identifying the calling script; killing this thread."
		Thread.current.kill
	end
	while true
		if reobj = regex.match(script.gets)
			ret = reobj.captures.compact
			if ret.length < 2
				return ret.first
			else
				return ret
			end
		end
	end
end

def matchfindword(*strings)
	regex = /#{strings.flatten.join('|').gsub('?', '([\w\d]+)')}/i
	unless script = Script.self
		respond "Unknown script is asking to use matchfindword!  Cannot process request without identifying the calling script; killing this thread."
		Thread.current.kill
	end
	while true
		if reobj = regex.match(script.gets)
			ret = reobj.captures.compact
			if ret.length < 2
				return ret.first
			else
				return ret
			end
		end
	end
end

def send_scripts(*messages)
	messages.flatten!
	messages.each { |message|
		Script.namescript_incoming(message)
	}
	true
end

def status_tags(onoff="none")
	target = Script.self
	if onoff == "on"
		Script.status_scripts.push(target) unless Script.status_scripts.include?(target)
		echo("Status tags will be sent to this script.")
	elsif onoff == "off"
		Script.status_scripts.delete(target)
		echo("Status tags will no longer be sent to this script.")
	else
		if Script.status_scripts.include?(target)
			Script.status_scripts.delete(target)
			echo("Status tags will no longer be sent to this script.")
		else
			Script.status_scripts.push(target)
			echo("Status tags will be sent to this script.")
		end
	end
end

def stop_script(*target_names)
  numkilled = 0
  target_names.each { |target_name|
	condemned = Script.index.find { |s_sock| s_sock.name =~ /^#{target_name}/i }
	if condemned.nil?
		respond("--- Lich: '#{Script.self}' tried to stop '#{target_name}', but it isn't running!")
	else
		if condemned.name =~ /^#{Script.self.name}$/i
			exit
		end
		condemned.kill
		respond("--- Lich: '#{condemned}' has been stopped by #{Script.self}.")
		numkilled += 1
	end
  }
  if numkilled == 0
	  return false
  else
  	return numkilled
  end
end

def running?(*snames)
	snames.each { |checking| (return false) unless (Script.index.find { |lscr| lscr.name =~ /^#{checking}$/i } || Script.index.find { |lscr| lscr.name =~ /^#{checking}/i }) }
	true
end

def force_start_script(script_name,cli_vars=[])
	base_name = script_name.dup
	script_name = "#{$script_dir}#{script_name}.lic"
	s_files = Dir.entries($script_dir)
	if (fname = s_files.find { |exists| exists =~ /\b#{base_name}\.lic/i }).nil?
		if (fname = s_files.find { |exists| exists =~ /\b#{base_name}.+\.lic/i }).nil?
			echo("#{base_name} was not found!")
			return false
		end
	end
	start_script($script_dir + fname,cli_vars)
end

def start_scripts(*script_names)
	script_names.flatten.each { |script_name|
		start_script(script_name)
		sleep 0.02
	}
end

def start_script(script_name,*cli_vars)
	cli_vars.flatten!
	if cli_vars.first.downcase == "safe"
		run_safe = true
		cli_vars.shift
	else
		run_safe = false
	end
	if script_name.split(/\/|\\/).length == 1
		base_name = script_name
		script_name = "#{$script_dir}#{script_name}.lic"
		s_files = Dir.entries($script_dir)
		if Script.index.find { |running| running.name.to_s.chomp == base_name.to_s or running.name.to_s.chomp == base_name.to_s + " (paused)" }
			echo("#{base_name} is already running!")
			return nil
		elsif !(s_files.find { |exists| exists =~ /\b#{base_name}\.(?:lic|rbw?|gz|Z)(?:gz|Z)?/i })
			echo("#{base_name} was not found!")
			return nil
		end
	else
		base_name = script_name.split(/\/|\\/).last.gsub(/\.(?:lic|rbw?|gz|Z)(?:gz|Z)?/i, '')
	end
	Thread.new {
		begin
			script = Script.new(base_name,cli_vars)
			script.setup_labels(script_name, run_safe)
		rescue
			respond("--- Lich: error reading script file: #{$!}")
			Thread.current.kill
		end
		script.set_safe if defined?(All_Safe)
		_current_label_ = script.fetch_next_label
		begin
			if script.safe?
				while _current_label_
					eval("$SAFE = 3\n#{_current_label_}",nil,script.name,script.line_no[script.current_label])
					script = Script.self
					_current_label_ = script.fetch_next_label
				end
			else
				while _current_label_
					eval(_current_label_,nil,script.name,script.line_no[script.current_label])
					script = Script.self
					_current_label_ = script.fetch_next_label
				end
			end
			script.kill
			respond("--- Lich: #{script} finished.") unless script.quiet_exit
		rescue SystemExit
			script.kill
			respond("--- Lich: #{script} has exited.") unless script.quiet_exit
		rescue SyntaxError
			script.kill
			respond("--- SyntaxError: #{$!}")
			respond($!.backtrace[0..2]) if $LICH_DEBUG
			respond("--- Lich: cannot execute #{script}, aborting.")
		rescue ScriptError
			script.kill
			respond("--- ScriptError: #{$!}")
			respond($!.backtrace[0..2]) if $LICH_DEBUG
			respond("--- Lich: #{script} has exited.")
		rescue
			script.kill
			respond("--- Error: #{script}: #{$!}")
			respond($!.backtrace[0..2]) if $LICH_DEBUG
			respond("--- Lich: #{script} has exited.")
		rescue NoMemoryError
			script.kill
			respond("--- NoMemoryError: #{$!}")
			respond($!.backtrace[0..2]) if $LICH_DEBUG
			respond("--- Lich: #{script} has exited.")
		rescue Exception
			if $! == JUMP
				retry if (_current_label_ = script.fetch_next_label) and _current_label_ != JUMP_ERROR
				script.kill
				respond("--- Label Error: `#{script.jump_label}' was not found, and no `LabelError' label was found!")
				respond($!.backtrace[0..2]) if $LICH_DEBUG
				respond("--- Lich: #{script} has exited.")
			else
				script.kill
				respond("--- Exception: #{$!}")
				respond($!.backtrace[0..2]) if $LICH_DEBUG
			 	respond("--- Lich: #{script} has exited.")
			end
		end
		_current_label_, script = nil, nil
	}
	sleep 0.1 if Script.self
	true
end

def force_start_wizard_script(name,cli_vars=[])
	start_wizard_script(name,cli_vars,true)
end

def start_wizard_script(name, cli_vars=[], force=false, wiz_dir = $LICHCONFIG['Wizard Directory'])
	script_dir = $script_dir.dup
	file_list = Dir.entries(script_dir)[2..-1]
	file_dir = script_dir.dup
	if wiz_dir.nil?
		wiz_dir = ''
	end
	found = file_list.find { |val| val =~ /^#{name}\.(?:cmd|wiz)/i }
	if found.nil?
		found = file_list.find { |val| val.downcase =~ /^#{name}.+\.(?:cmd|wiz)/i }
	end
	if found.nil?
		if File.exists?(File.join(wiz_dir, "Gemstone", "Scripts"))
			file_dir = File.join(wiz_dir, "Gemstone", "Scripts")
			wiz_file_list = Dir.entries(file_dir)
		elsif File.exists?(ENV['HOME'] + "/.wine/drive_c/Program Files/SIMU/WIZARD/Gemstone/Scripts")
			wiz_file_list = Dir.entries(ENV['HOME'] + "/.wine/drive_c/Program Files/SIMU/WIZARD/Gemstone/Scripts")[2..-1]
			file_dir = ENV['HOME'] + "/.wine/drive_c/Program Files/SIMU/WIZARD/Gemstone/Scripts"
		elsif File.exists?("/Program Files/SIMU/WIZARD/Gemstone/Scripts")
			wiz_file_list = Dir.entries("/Program Files/SIMU/WIZARD/Gemstone/Scripts")
			file_dir = "/Program Files/SIMU/WIZARD/Gemstone/Scripts"
		else
			wiz_file_list = []
		end
		wiz_file_list = wiz_file_list.find_all { |wfile| wfile =~ /\.cmd$|\.wiz$/i }
		if wiz_file_list.empty?
			respond("--- Lich: unable to locate `#{name}'! If you're sure it exists, copy it to your Lich directory.")
			return nil
		else
			found = wiz_file_list.find { |wfile| wfile =~ /^#{name}\.(?:cmd|wiz)/i }
			if found.nil?
				found = wiz_file_list.find { |wfile| wfile =~ /^#{name}.+\.(?:cmd|wiz)/i }
			end
		end
		if found.nil?
			respond("--- Lich: unable to locate `#{name}'! If you're sure it exists, copy it to your Lich directory.")
			return nil
		end
	end
	if cli_vars.first =~ /reverse/i
		rev = true
		cli_vars.shift
	else
		rev = false
	end
	if (Script.index.find { |runcheck| runcheck.name == found } and force == false) then respond("--- Lich: #{found} is already running!"); return nil end
	Thread.new {
	  begin
		script = Script.new(found,cli_vars)
		script.init_wizard_script(found)
		if rev == true
			script.load_wizard_lines(file_dir + "/#{found}",true)
		else
			script.load_wizard_lines(file_dir + "/#{found}")
		end
		script.set_as_good
		script.set_safe
		while true
			break if script.process_next_wizard_line.nil?
		end
		script.kill
	  	respond("--- Lich: #{script} has finished.")
	  rescue SyntaxError
		script.kill
	  	respond("--- Lich: error around line #{script.stackptr}: #{$!}")
	  rescue SystemExit
		script.kill
	  	respond("--- Lich: #{script} has exited.")
	  rescue SystemCallError
		script.kill
	  	respond("--- Lich: error around line #{script.stackptr}: #{$!}")
	  rescue
		script.kill
	  	respond("--- Lich: error around line #{script.stackptr}: #{$!}")
	  rescue NoMemoryError
	  	script.kill
		respond("--- Lich: #{$!}")
	  end
	  script = nil; found = nil; wiz_file_list = nil; file_list = nil; found = nil
	}
	true
end

def load_favs(lich_dir, script_dir, q=nil)
	s_files = Dir.entries(script_dir)[2..-1]
	begin
		file = File.open("#{lich_dir}favorites.txt"); favoritesdata = file.readlines; file.close; file = nil
		favorites = Array.new
		if checkname
			favorites = favoritesdata.find_all { |line| line =~ /^(?:ALL|#{checkname}):/ }
			favorites.sort!
			if (favorites.empty? && favoritesdata.find_all{ |line| line =~ /^\w+:/ }.empty?)
				favoritesdata.each { |val| favorites.push('ALL:' + val) }
				file = File.open(lich_dir + 'favorites.txt','w'); file.puts(favorites); file.close; file = nil
			elsif favorites.empty?
				favorites = favoritesdata.dup
			end
		else
			favorites = favoritesdata.reject { |line| line !~ /^ALL:/ }
		end
		favorites.compact!
	rescue
		favorites = []
	end
	favorites = favorites.collect { |line| line.sub(/[^:]+:/, '') }
	loaded = Array.new
	until favorites.empty?
		new_script = favorites.shift.strip
		if Script.find(new_script)
			nil	# Already running, skip it
		elsif s_files.find { |exists| exists =~ /^#{new_script}.*\.lic/ }
			if q == true
				start_script("#{script_dir}#{new_script}.lic",["quiet"])
			else
				start_script("#{script_dir}#{new_script}.lic")
			end
			loaded.push(new_script)
		else
			respond("--- Lich: '#{new_script}' was not found!")
		end
	end
	loaded
end

def dump_to_log(log_dir)
 begin
	file = File.open("#{log_dir}lich-log.txt", "w")
	file.print("--- Dump of the up- and down-streams of data as seen by the Lich (this includes all status lines, etc.) ---\r\n")
	file.print("\tLich v#{$version}  " + Time.now.to_s)
	file.print("\r\n\r\n\r\n===========\r\nFrom the Game Host to Your Computer\r\n==========\r\n\r\n")
	file.puts($_SERVERBUFFER_.history + $_SERVERBUFFER_)
	file.print("\r\n\r\n\r\n\r\n==========\r\nFrom Your Computer to the Game Host\r\n==========\r\n\r\n")
	file.puts($_CLIENTBUFFER_.history + $_CLIENTBUFFER_)
	respond("--- Lich: '#{log_dir}lich-log.txt' written successfully.  If you want to keep it, don't forget to rename it or next time it'll be overwritten!")
 rescue
	$stderr.puts("--- Lich encountered an error and cannot write to log; message was:\n--- #{$!}")
 ensure
 	psinet_log = nil
	simu_log = nil
	file.close
 end
end

def respond(first = "", *messages)
	if $_CLIENT_.closed? then return end
	str = ''
	begin
		if first.class == Array
			first.flatten.each { |ln| str += sprintf("%s\r\n", ln.to_s.chomp) }
		else	
			str += sprintf("%s\r\n", first.to_s.chomp)
		end
		messages.flatten.each { |message| str += sprintf("%s\r\n", message.to_s.chomp) }
		if $stormfront
			str = "<output class=\"mono\"/>\r\n#{str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')}<output class=\"\"/>\r\n"
		elsif $SIMUGAME
			str = "\034GSw00008ignore this\r\n#{str}\034GSw00008ignore this\r\n"
		end
		$_CLIENT_.write(str)
	rescue
		puts $!.to_s if $LICH_DEBUG
	end
end

def find_hosts_file(windir = nil)
	if !windir.nil?
		winxp = "\\system32\\drivers\\etc\\"
		win98 = "\\"
		if File.exists?(windir + winxp + "hosts.bak")
			heal_hosts(windir + winxp)
			return windir + winxp
		elsif File.exists?(windir + win98 + "hosts.bak")
			heal_hosts(windir + win98)
			return windir + win98
		elsif File.exists?(windir + winxp + "hosts")
			return windir + winxp
		elsif File.exists?(windir + win98 + "hosts")
			return windir + win98
		end
	end
	if Dir.pwd.to_s[0..1] =~ /(C|D|E|F|G|H)/
		prefix = "#{$1.dup}:"
	else
		prefix = String.new
	end
	winxp_pro = "#{prefix}\\winnt\\system32\\drivers\\etc\\"
	winxp_home = "#{prefix}\\windows\\system32\\drivers\\etc\\"
	win98 = "#{prefix}\\windows\\"
	nix = "/etc/"
	[ winxp_pro, winxp_home, win98, nix ].each { |windir|
		if File.exists?(windir + "hosts.bak") or File.exists?(windir + "hosts")
			heal_hosts(windir)
			return windir
		end
	}
	winxp_pro.sub!(/[A-Z]:/, '')
	winxp_home.sub!(/[A-Z]:/, '')
	win98.sub!(/[A-Z]:/, '')
	[ "hosts" ].each { |fname|
		[ "C:", "D:", "E:", "F:", "G:" ].each { |drive|
			[ winxp_pro, winxp_home, win98 ].each { |windir|
				if File.exists?(drive + windir + "hosts.bak") or File.exists?(drive + windir + "hosts")
					heal_hosts(drive + windir)
					return drive + windir
				end
			}
		}
	}
	$stderr.puts("Fatal error! Your local hosts file cannot be located!")
	nil
end

def hack_hosts(hosts_dir, simu_ip)
	if hosts_dir[-1..-1] !~ /\/\\/
		hosts_dir += File::SEPARATOR
	end
	at_exit { heal_hosts(hosts_dir) }
	begin
		begin
			unless File.exists?("%shosts.bak" % hosts_dir)
				File.open("%shosts" % hosts_dir) { |file|
					File.open("%shosts.sav" % $lich_dir, 'w') { |f|
						f.write(file.read)
					}
				}
			end
		rescue
			File.unlink("#{$lich_dir}hosts.sav") if File.exists?("#{$lich_dir}hosts.sav")
		end
		if File.exists?("%shosts.bak" % hosts_dir)
			sleep 1
			if File.exists?("%shosts.bak" % hosts_dir)
				heal_hosts(hosts_dir)
			end
		end
		File.open("%shosts" % hosts_dir) { |file|
			File.open("%shosts.bak" % hosts_dir, 'w') { |f|
				f.write(file.read)
			}
		}
		File.open("%shosts" % hosts_dir, 'w') { |file|
			file.puts "127.0.0.1\t\tlocalhost\r\n127.0.0.1\t\t%s" % simu_ip
		}
	rescue SystemCallError
		$stderr.puts $!
		$stderr.puts $!.backtrace
		exit(1)
	end
end

def heal_hosts(hosts_dir)
	if hosts_dir[-1..-1] !~ /\/\\/
		hosts_dir += File::SEPARATOR
	end
	begin
		if File.exists? "%shosts.bak" % hosts_dir
			File.open("%shosts.bak" % hosts_dir) { |file|
				File.open("%shosts" % hosts_dir, 'w') { |f|
					f.write(file.read)
				}
			}
			File.unlink "%shosts.bak" % hosts_dir
		end
	rescue
		$stderr.puts $!
		$stderr.puts $!.backtrace
		exit(1)
	end
end

def open_gs(simu_quad_ip, simu_port)
	puts("Connecting to the real game host...")
	if ARGV.find { |val| val =~ /\-\-fake\-sf/i }
		puts("Identifying as SF.")
		$_SERVER_ = TCPSocket.open("storm.gs4.game.play.net", 10024)
		$_FAKE_STORMFRONT = true
		$stormfront = true
	else
		$_SERVER_ = TCPSocket.open(simu_quad_ip, simu_port)
	end
	puts("Connection with the game host is open.")
end

def open_client(listener)
	puts("Pretending to be the game host, and waiting for game client to connect to us...")
	$_CLIENT_ = listener.accept
	puts("Connection with the local game client is open.")
end

if ENV['OS'] =~ /win/i
	def launch_sge_win(server)
		if $LICHCONFIG['SGE Directory'] and File.exists? File.join($LICHCONFIG['SGE Directory'], 'Sge.exe')
			file = File.join($LICHCONFIG['SGE Directory'], "Sge.exe")
		else
			file = "/Program Files/SIMU/SGE/Sge.exe"
		end
		Thread.new { system(file) }
		nil
	end
else
	def launch_sge_nix(server)
		begin
			fork {
				server.close
				Process.euid = Process.uid
				Process.egid = Process.gid
				exec("wine '#{ENV['HOME']}/.wine/drive_c/Program Files/SIMU/SGE/Sge.exe'")
			}
		rescue NotImplementedError
			Thread.new {
				system("sudo -u `id -run` wine '#{ENV['HOME']}/.wine/drive_c/Program Files/SIMU/SGE/Sge.exe'")
			}
		end
		nil
	end
end

def launch_sge_user(lich_dir)
	begin
		data = File.open("#{lich_dir}launch.txt") { |file| file.readlines }
	rescue SystemCallError
		return false
	end
  	launchn = 0
	data.delete_if { |line| line =~ /^#/ }
	data.each { |prog|
		unless prog.chomp.empty?
			if ENV['OS'] =~ /win/i
				Thread.new { system("#{prog.chomp}") }
			else
				fork {
					begin
						Process.euid = Process.uid
					rescue
						$stderr.puts $!
						$stderr.puts $!.backtrace
					end
					exec("#{prog.chomp}")
				}
			end
		end
	}
	nil
end

class File
	def File.expand_registry_str(string)
		re = /%([^%]+)%/.match(string)
		re.captures.compact.each { |var| string.sub!(/%#{var}%/, ENV[var]) }
		string
	end
end

begin
	undef :abort
	alias :mana :checkmana
	alias :mana? :checkmana
	alias :health :checkhealth
	alias :health? :checkhealth
	alias :spirit :checkspirit
	alias :spirit? :checkspirit
	alias :stamina :checkstamina
	alias :stamina? :checkstamina
	alias :stunned? :checkstunned
	alias :bleeding? :checkbleeding
	alias :reallybleeding? :checkreallybleeding
	alias :dead? :checkdead
	alias :hiding? :checkhidden
	alias :hidden? :checkhidden
	alias :hidden :checkhidden
	alias :checkhiding :checkhidden
	alias :standing? :checkstanding
	alias :stance? :checkstance
	alias :stance :checkstance
	alias :joined? :checkgrouped
	alias :checkjoined :checkgrouped
	alias :group? :checkgrouped
	alias :myname? :checkname
	alias :active? :checkspell
	alias :righthand? :checkright
	alias :lefthand? :checkleft
	alias :righthand :checkright
	alias :lefthand :checkleft
	alias :mind? :checkmind
	alias :checkactive :checkspell
	alias :forceput :fput
	alias :send_script :send_scripts
	alias :stop_scripts :stop_script
	alias :kill_scripts :stop_script
	alias :kill_script :stop_script
	alias :fried? :checkfried
	alias :webbed? :checkwebbed
	alias :pause_scripts :pause_script
	alias :roomdescription? :checkroomdescrip
	alias :prepped? :checkprep
	alias :checkprepared :checkprep
	alias :unpause_scripts :unpause_script
	alias :priority? :setpriority
	alias :checkoutside :outside?
	alias :toggle_status :status_tags
rescue
	STDERR.puts($!)
	STDERR.puts($!.backtrace)
end
