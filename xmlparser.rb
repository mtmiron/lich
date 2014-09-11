class XMLParser
   @@stream ||= {}
	@@tags ||= {}
	def XMLParser.stream
		@@stream
	end
	def XMLParser.tags
		@@tags
	end

	class Tag
		attr_accessor :element, :attributes
		def initialize(element, attributes)
			@element, @attributes = element, attributes
			XMLParser.tags[@attributes['id']] = self
		end
	end

   class Stream
      @@context ||= []
      def initialize(name)
         @name, @buffer = name, String.new
         XMLParser.stream[@name] = self
      end
      def push
         @@context.push self
      end
      def pop
         @@context.delete self
      end
      def write(string)
         @buffer += string
      end
      def clear
         @buffer = String.new
      end
      def to_s
         @buffer
      end
      def Stream.current
         @@context.last || XMLParser.stream['main']
      end
   end

CALLBACKS['streamWindow'] = proc { |hash|
	s = (@@stream[hash['id']] || Stream.new(hash['id']))
	s.push
}
CALLBACKS['pushStream'] = CALLBACKS['streamWindow']
CALLBACKS['popStream'] = proc { |hash|
   @@stream[hash['id']].pop
}
CALLBACKS['clearStream'] = proc { |hash|
   @@stream[hash['id']].clear
}

end
