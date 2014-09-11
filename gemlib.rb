class FixNum
	def match(num)
		self == num
	end
end

class Gem
	include Comparable
	include Enumerable

	attr_accessor :noun, :value, :description, :geo, :purifiable, :count, :quality
	alias :price :value
	alias :price= :value=
	alias :string :description
	alias :string= :description=

	@@hash ||= {}

	def initialize(desc, noun = desc.slice(/[^\s]+$/))
		@description, @noun = desc, noun
		@@hash[@description] = self
	end

	def to_s
		@noun
	end

	def <=>(gem)
		@value <=> gem.value
	end
=begin
	def ===(gem)
		gem.match(@noun) ||
		gem.match(@description) ||
		gem.match(@value)
	end
=end
	def each
		for val in @@hash.values
			yield val
		end
	end

	def Gem.method_missing(*args, &block)
		gem = @@hash.values.first
		meths = Enumerable.instance_methods

		raise NoMethodError unless meths.include? args.first.to_s
		gem.__send__(*args, &block)
	end
=begin
	def Gem.find(*args, &block)
		@@hash.values.first.__send__(:find, *args, &block)
	end
=end
	def Gem.list
		@@hash
	end

	def Gem.hash
		@@hash
	end

	def Gem.[](obj)
		name = obj.to_s
		ndup = name.dup
		Gem.load if @@hash.empty?

		unless value = @@hash[name] || @@hash[name.strip.downcase] ||
			            @@hash[ndup.sub!(/[^\s]+\s*/, '')] ||
			            @@hash[ndup.strip.downcase]
			ary = @@hash.values.sort
			value = ary.find { |gem| gem.noun =~ /\b#{name}\b/i } ||
			        ary.find { |gem| gem.noun =~ /^#{name}/i } ||
			        ary.find { |gem| gem.description =~ /\b#{name}\b/i } ||
			        ary.find { |gem| gem.description =~ /^#{name}/i }
		end

		value
	end

	def Gem.load(fname = File.join($data_dir, "gems.dat"))
		bindata = File.open(fname, "rb") { |f| f.read }
		@@hash = Marshal.load(bindata)
	end

	def Gem.dump(fname = File.join($data_dir, "gems.dat"))
		bindata = Marshal.dump(@@hash)
		raise RuntimeError, "no gem data to dump to file!" if @@hash.empty?
		File.open(fname, "wb") { |f| f.write bindata }
	end

end

Gems = Gem
