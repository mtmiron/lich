def match(label, string)
	strings = [ label, string ]
	strings.flatten!
	unless port = Script.find then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
	if strings.empty? then echo("Error! 'match' was given no strings to look for!") ; sleep 1 ; return false end
	unless strings.length == 2
		if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
		while line_in = port.gets
			strings.each { |string|
				if line_in =~ /#{string}/ then return $~.to_s end
			}
		end
	else
		if port.respond_to?(:match_stack_add)
			port.match_stack_add(strings.first.to_s, strings.last)
		else	
			port.match_stack_labels.push(strings[0].to_s)
			port.match_stack_strings.push(strings[1])
		end
	end
end

def matchtimeout(secs, *strings)
	unless port = Script.find then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
	unless (secs.class == Float || secs.class == Fixnum) then echo('matchtimeout error! You appear to have given it a string, not a #! Syntax:  matchtimeout(30, "You stand up")') ; return false end
	if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
	match_string = false
	strings.flatten!
	if strings.empty? then echo("matchtimeout without any strings to wait for!") ; sleep 1 ; return false end
	regexpstr = strings.join('|')
	watcher_thread = Thread.new {
		while line_in = port.gets
			if line_in =~ /#{regexpstr}/i
				match_string = line_in.dup
				break
			end
		end
	}
	watcher_thread.join(secs.to_f)
	watcher_thread.kill if watcher_thread.alive?
	return match_string
end

def matchbefore(*strings)
  strings.flatten!
  unless port = Script.find then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
  if strings.empty? then echo("matchbefore without any strings to wait for!") ; return false end
  if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
  regexpstr = strings.join('|')
  loop { if (line_in = port.gets) =~ /#{regexpstr}/ then return $`.to_s end }
end

def matchafter(*strings)
  strings.flatten!
  unless port = Script.find then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
  if strings.empty? then echo("matchafter without any strings to wait for!") ; return end
  if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
  regexpstr = strings.join('|')
  loop { if (line_in = port.gets) =~ /#{regexpstr}/ then return $'.to_s end }
end

def matchboth(*strings)
  strings.flatten!
  unless port = Script.find then echo("An unknown script thread tried to fetch a game line from the queue, but Lich can't process the call without knowing which script is calling! Aborting...") ; Thread.current.kill ; return false end
  if strings.empty? then echo("matchafter without any strings to wait for!") ; return end
  if port.unique then echo("this script is set as unique -- a 'match' will cause it to hang permanently! Aborting") ; sleep 1 ; return false end
  regexpstr = strings.join('|')
  loop { if (line_in = port.gets) =~ /#{regexpstr}/ then break end }
  return [ $`.to_s, $'.to_s ]
end
