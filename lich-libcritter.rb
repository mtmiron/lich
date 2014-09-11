class Critter
	unless defined?(LIST)
		LIST = []
	end
	attr_reader :id, :name, :level, :race, :type, :undead, :geo
	attr_accessor :as, :ds, :cs, :td, :attacks, :mb
	def initialize(id,name,level,race,type,undead=false,geo=nil)
		@id,@name,@level,@race,@type,@undead,@geo = id,name,level.to_i,race,type,undead,geo
		LIST.push(self) unless LIST.find { |critter| critter.name == @name }
	end
end
