#!/usr/bin/env ruby
require 'socket'

class NilClass
	def method_missing(*args)
		nil
	end
end

class FalseClass
	def method_missing(*args)
		false
	end
end

class TrueClass
	def method_missing(*args)
		true
	end
end

class String
	def write
		fail UserError, "Target not found: #{self}" unless target = Client.find(self)
		target.write(self)
	end
end

class TCPSocket
	def _dump(depth=nil)
		Marshal.dump(nil)
	end
	def TCPSocket._load(string)
		nil
	end
end

class UserError < Exception; end

class Message
	TERMINATOR = "\000\000\000\000"
	MAX_SIZE = 5000
	attr_accessor :type, :data, :from, :to, :authentication, :other, :timestamp
	def initialize(type,data,from = Thread.current['client'],to = nil,authentication = nil,other = nil)
		@from,@to,@data,@other = from,to,data,other
		@type,@authentication = type,authentication
		@timestamp = Time.now
	end
	def Message.make(*strings)
		return strings.first if strings.length == 1 and strings.first.kind_of? Message
		strings.each { |msg|
			fail UserError, "The message you attempted to send is too large." if msg.to_s.length > Message::MAX_SIZE
		}
		begin
			err = false
			new(*strings)
		rescue ArgumentError
			fail $! if err
			strings.push(:chat)
			err = true
			retry
		end
	end
	def expand_target
		begin
			unless target = Client.find(@to)
				target = Channel.find(@to)
			end
			@to = target
		rescue
			@to = nil
		end
	end
	def send(sock = nil)
		sock = @to if !sock
		expand_target if @to.kind_of? String
		sock.write self
	end
end
