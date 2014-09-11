class ZlibSocket
	private_class_method :new
	def initialize(io)
		@writer = Zlib::GzipWriter.wrap(io)
		@reader = Zlib::GzipReader.wrap(io)
		@writer.sync = @reader.sync = true
	end
	def ZlibSocket.wrap(io)
		new(io)
	end
	def gets(sep = nil)
		@reader.gets(sep)
	end
	def puts(*strings)
		@writer.puts(*strings)
	end
	def write(*args)
		@writer.write(*args)
	end
	def read(*args)
		@reader.read(*args)
	end
end

