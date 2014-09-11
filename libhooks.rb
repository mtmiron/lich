# Strings typed by the user that Lich recognizes, along with what to do if they're seen.  Note that any string not starting with the standard Lich character (default is a semicolon) is ignored without being checked, and that the Lich character is stripped off the user-input before matching begins

module UserHooks
# Main help info/list of commands
Hook.register(/^help[\s\w]*$/i) { |str|
	cmdhelp = Hash.new

	cmdhelp['wrap'] = <<WRAP
As of v3.44, this command is only available in *NIX environments.

Lich itself can interpret and execute Wizard, StormFront, and Ruby scripts; this command allows the program to act as a "middleman" of sorts to any external program (which is presumably an interpreter -- Python or Perl, for instance).  It essentially "wraps" itself around the external interpreter, communicating through the external program's STANDARD INPUT and STANDARD OUTPUT.

If you don't know what "standard input" and "standard output" are referring to, you likely won't be needing this command; it's meant primarily for advanced end-users who'd rather write scripts in their favorite language than in Ruby.  If your curiosity prevails, google "programming standard input tutorial" and read to your heart's content.

For a detailed explanation of how to do this, see the text file "#{$lich_dir}Wrapping a Script.txt".  For an example using PERL, see the script "template.pl" in your Lich script directory.  Supported options:

  ;wrap {scriptname}.{ext}  ....  Start a given script.  For example:   ;wrap myscript.pl
WRAP

	cmdhelp['log'] = <<LOG
This command will copy the entire contents of Lich's buffers and caches (which is effectively the entire history of sent and received lines since you logged in) to a file that, unlike the temporary caches, Lich will not delete automatically when you log out.

Note that absolutely all data Lich has been witness to is included, which means raw and unfiltered status data sent by the game to your local client (and in some cases vice versa) will also be included in the resulting text file.
LOG

	cmdhelp['stats'] = <<STATS
This just echoes some internal program statistics and current environment info; it's purely for debugging purposes (and to satisfy curiosity).
STATS

	cmdhelp['magic'] = <<MAGIC
This allows you to view Lich's tracking of your currently active spells (and spell-like effects) and their remaining duration(s).  Recognized options include:

 ;magic help  .......  Further information about the related options.
 
 ;magic save  .......  Save a copy of your currently active spells and Gift of Lumnis information on Lich's server for later use.
 
 ;magic load  .......  Load a copy of your information that you've previously saved on the server.  This is primarily of use to people who find themselves going back and forth between computers.

 ;magic set {#} {#} .  Set the given spell # to the given minutes remaining.  For example, `;magic set 406 120' would set 406 (brights) as having 120 minutes remaining.
 
 ;magic clear [#]  ..  Without a spell number, clears the entire list of currently-active spells.  If given a spell #, clears only the given spell.
 
 ;magic reset [#]  ..  Synonym for clear.

All of the previous commands are implemented by the `infomonitor.lic' script, and as such, it must be running for both spell tracking and viewing to be usable.

A related feature (but one implemented by a different script) is the automatic spelling up of yourself, a target, or even anyone who comes along and taps you.  For info about those and listing all known spell-like effects, refer to `;spellup help'.
MAGIC

	cmdhelp['send'] = <<SEND
Unlike conventional Wizard and StormFront scripts, what the user types and sends to the game is not (by default) seen by active scripts -- despite it appearing in the user's game window, the mechanics of how Lich works makes it totally invisible to running scripts unless they specifically request to be sent local user commands.

Instead, you can make use of this command: it sends whatever you specify to all currently active scripts; scripts receive this user-defined data in the same exact way they receive game-sent data, so you can use it to "trick" scripts into seeing lines from the game that weren't actually sent, to respond to a script's question, or for anything else you can come up with to use it for.

Note that any lines sent with this command are *not* sent to the game; Lich simply passes the data to its scripts and nothing more.  Options:

 ;send {data}  ..............  Send all active scripts whatever you enter as {data}
 
 ;send to {script} {data}  ..  Instead of sending all running scripts data, send it to only the specified script.
 
 ;s  ........................  Can be used instead of the whole word "send."  Is otherwise identical to the above.
SEND

	cmdhelp['list'] = <<LIST
This command lists the currently active scripts; any paused scripts are labeled as such, and the order in which the scripts were originally started is preserved.  Can be appreviated as `;l' for convenience.
LIST

	cmdhelp['kill'] = cmdhelp['stop'] = <<KILL
This command halts a running script and essentially clears out the resources that were being used by it; options:

 ;kill [script]  .....  If no script name is given, kills the most recently started script.  If a name is given, kills only the specified script.
 
 ;kill all  ..........  Stops all active scripts; any script that has registered itself with the `no_kill_all' command is ignored by this command.
 
 ;stop  ..............  Synonym for `;kill', otherwise identical to above.
 
 ;k  .................  Also a synonym.
 

Note that there is no way to make a script ignore a targetted or untargetted `;kill' command; only `;kill all' can be set as being ignored.  For example, `lichnet.lic' registers itself as needing to ignore a `;kill all', but will be stopped just like any other script by a `;kill lichnet' command.

For further information on `no_kill_all', refer to `;man no_kill_all'.
KILL

	cmdhelp['pause'] = <<PAUSE
This command will temporarily pause a script; for info about unpausing scripts, refer to `;help unpause'.  Options:

 ;pause [script]  .....  Pause the most recently started (but not already paused) script, or the specified script if a name is provided.
 
 ;pause all  ..........  Pause all currently active scripts that have not registered themselves with the `no_pause_all' command.
 
 ;p  ..................  Synonym for `;pause', otherwise identical to above.

Refer to `;help kill' for more info on ignoring `;pause all' and behavior thereof, as it's identical to the `;kill all' behavior.  For more on the `no_pause_all' command, refer to `;man no_pause_all'.
PAUSE

	cmdhelp['purge'] = <<PURGE
This command deletes the currently cached history of game-sent and user-sent data (both the RAM and hard disk portions), empties all active script's input/output memory buffers (note that this can result in game data not being seen by scripts, since it may be deleted before they have a chance to check it), and unconditionally triggers a general "garbage collection" sweep (details on this are beyond the scope of this documentation, but suffice it to say it's done automatically and there's no need to initiate it with this command).

Note that a subsequent `;log' command will not save any data that was previously deleted by a `;purge' command.
PURGE

	cmdhelp['exec'] = cmdhelp['execq'] = <<EXEC
This handy little feature allows you to write and run a script truly "on-the-fly," without any files on the hard disk or switching to/from programs being involved.  Simply type out whatever script you want Lich to run following the `;exec' command (simulating moving down to the next line with semicolons), and when finished hit enter.  A semicolon is the same thing as hitting enter to move down a line in the Ruby language, so you can have as long and complex an "exec" script as you want to bother typing.  Options:

 ;exec {miniscript}  ...  Execute the specified `miniscript' exactly like any other script, but without any files being involved.
 
 ;execq {miniscript}  ..  Identical to above, but will silence the notification Lich generates when a script starts and ends.
 
 ;e  ...................  Synonym for `;exec'.
 
 ;eq  ..................  Synonym for `;execq'.

Note that since `;eq' generates no actual notice that a script starts or ends, it can be used along with aliases to simulate your own complex "Lich commands."  For example, I keep an alias for `get' that starts a miniscript with nothing but the command `fetchloot', which is a Lich script command that picks up and puts away loot on the ground (refer to `;man fetchloot' for more on that).

There is no limit to how many exec scripts can be running simultaneously; they'll be numbered starting at 1 and can be referred to if necessary by supplying their full name (e.g., `;kill exec3', etc.).
EXEC

	cmdhelp['spellshorts'] = <<SPELLSHORTS
This will alter the lines you send to the game if they consist only of "{number}" or "{number} target".  For example, "401" would be changed to "incant 401" before being sent.  "406 somebody" would be altered to be "prep 406 (carriage-return) cast at somebody", and so on.
SPELLSHORTS

	cmdhelp['tips'] = <<TIPS
- The program website -- http://lich.gs4groups.com	-- has a good deal of information; don't overlook the links page for quick references.

- There are a number of informational text files (including brief script tutorials) in your Lich program directory (Lich is currently installed in `#{$lich_dir}').

- Lich has a manual that's viewable in your game window; just type `#{$clean_lich_char}man' for details.

- The script repository is the best place to look for both user-written scripts as well as the latest versions of all the scripts the author of Lich wrote (including those bundled with the install).  Type `#{$clean_lich_char}repository' for further details.

- Lich's aliases have regular expression support.

- The author's most-used (and favorite) script is "goto.lic", which is an `any-room-to-any-room movement script' that utilizes Lich's built-in pathfinding capabilities to plot the shortest route between your origin and your destination.  If you haven't done so yet, have a look at it (type `#{$clean_lich_char}goto' for more details).

- The author's almost-as-often-used (and second favorite) script is "healme.lic", which requires no interaction whatsoever to heal you completely using herbs.  Type `#{$clean_lich_char}repository info healme' for further details.

- Lich can properly recognize and execute Wizard and StormFront scripts it finds in its script directory no matter which front-end you're playing with.

- Lich can compensate for your type ahead limit, to a certain extent; unfortunately there is no way to do this perfectly, but it's particularly useful to avoid type ahead errors from scripts sending data at the same time the user is sending game commands.  Type `#{$clean_lich_char}ta help' for further details.

- The list of magical effects that Lich tracks the duration of is defined by a plain-text file in your Lich script directory.  The program installs with the file including all the necessary information for a number of combat maneuvers, CoL signs, Voln symbols, and Bard spellsongs, but that may not be enough for you.  The name of the file is "spell-list.txt" and you can add to/remove from/edit the file to your heart's content; if you make changes to it, simply kill and restart the "infomonitor.lic" script for the changes to take effect.
TIPS

	cmdhelp['gui'] = <<GUI
This command can be used in either of two methods.  The first allows for the display of most recognized Lich commands in a graphical popup console (including help information).  The second allows a script to be started and for its text output to be piped to a graphical popup console.  Examples:

  ;gui repository list  ...  This would execute the "repository" script, and display its output in a GUI console.
  ;gui help  ..............  This would display the main "help" information in a GUI console.
GUI

	cmdhelp['mapbrowser'] = <<MAPBROWSER
This allows for the viewing and editing of the map database (as used by the goto.lic script).  It should be self-explanatory, so give it a try.

Note, however, that any changes made do not effect the currently running Lich process -- what this means is that any changes you make can be written out to a file, but they won't take effect until you deliberately (re)load the map database (e.g. by typing `;goto reload' after manually moving the Map Browser's "map-mod.dat" file to the standard "map.dat" file).
MAPBROWSER

	cmdhelp['topics'] = proc { |string|
		n = '0'
		respond "The currently available Lich help topics are:"
		for t in cmdhelp.keys.sort
			respond sprintf("%s. %s", n.succ!, t.capitalize)
		end
	}

	cmd = str.chomp.sub(/\w+\s+/, '')
	if specific_info = cmdhelp[cmd]
		if specific_info.kind_of? Proc
			specific_info.call(cmd)
		else
			respond
			respond "#{$clean_lich_char}%s" % cmd.upcase
			respond specific_info
		end
		return
	end

respond <<HELP
---  The Lich Scripting Utility, v#{$version}  ---

    Script Control:
KILL [name]  .....  Kill last script, or optionally by name. Also recognized as 'stop' and 'k'.
KILL ALL  ........  Stops all scripts. Also works as 'ka' and 'STOP ALL' (abbreviations accepted).
PAUSE [name]  ....  Pause the given script, or the last unpaused script. Also 'p'.
PAUSE ALL  .......  Pause all active scripts. This is also recognized as 'pa'.
UNPAUSE [name]  ..  Unpause the given script, or the last paused one. Also 'u' and 'up'.
UNPAUSE ALL  .....  Unpause all currently paused scripts. Also recognized as 'ua' and 'upa'.
LIST  ............  Lists all currently running scripts. Also recognized as 'l'.
SEND {string}  ...  Local commands aren't seen by scripts. This sends all scripts a line. Also 's'.
SEND TO {name}  ..  Identical to SEND, but sends to only one script. Ex: ';send to calc [message]'.
DEBUG  ...........  Toggles on/off script verbose error reporting (slightly more info about errors).

    Remote Info Querying and other LichNet Features:
MAGIC  ...........  For use with the 'infomonitor' script; 'magic help' for specific information.
CHAT  ............  LichNet's chat command. ';chat help' for more detailed information about usage.
TUNEIN  ..........  Tune in to the server's chat net; character name will be part of the WHO list.
TUNEOUT  .........  Ignore the chat and hide char's name; private chats and info-checks still work.
WHO  .............  List the people tuned to the LNet chat. The 'lichnet' script must be running.
WHO {person}  ....  Check if a person is linked to LNet and whether they're tuned to the chat.
LOCATE {name}  ...  Locate someone currently linked to LichNet; you also have to be linked.
SPELLS {name}  ...  Display the active spells of someone linked to LichNet (their MAGIC data).
INFO {name}  .....  Display the statistics of someone linked to LichNet (their INFO data).
SKILLS {name}  ...  Display the skills of someone linked to LichNet (their SKILLS data).
HEALTH {name}  ...  Display the health, mana, and possibly stamina of someone (their HEALTH data).
REPOSITORY  ......  This will show help info pertaining to the script repository and its usage.

    Core Program Configuration:
TYPEAHEAD  .......  Set your typeahead limit compensation.  `typeahead help' for more.  Also 'ta'.
TAC  .............  TypeAheadClear, discards any queued commands in the type ahead buffer.
ALIAS  ...........  Lists your Lich aliases; these are global (i.e. they apply to all your chars).
ALIAS ADD/DEL  ...  Add or delete aliases from your Lich aliases list. 'alias help' for more info.
FAVS  ............  List the scripts currently on your favorites list (these are started at login).
FAVS ALL  ........  Lists any global favorites as well as all character-specific lists.
FAVS ADD {name}  .  Add a script to your character-specific favorites list; abbreviations accepted.
FAVS ADD ALL  ....  Same as 'FAVS ADD', but script is added to the global list (effects all chars).
FAVS DEL {name}  .  Delete a script from your character-specific favorites list; abbreviations okay.
FAVS DEL ALL  ....  Same as 'FAVS DEL', but delete the script from your global favorites list.
FAVS LOAD  .......  Load the scripts on your favorites list at anytime (the way Lich does at login).
RELOAD  ..........  Will reload the settings from your settings file and aliases file.

    Help and Miscellaneous Program Features:
GUI [parameters] .  See `help gui' for detailed information.
MAPBROWSER .......  See `help mapbrowser' for detailed information.
HELP [command]  ..  Displays this list, or if available the specified command's help information.
HELP TOPICS  .....  List all available `;help {cmd}' topics that can be viewed for specific info.
NOTES  ...........  Display a number of miscellaneous program notes and tips.
ABOUT  ...........  A paragraph about the program (application manifest): version, contact info, etc.
LOG  .............  Save temp caches to a persistent .txt file (dumps entire history as ASCII text).
STATS  ...........  CPU time used, size of Lich's RAM/HDD caches, time since login, etc.
PURGE  ...........  Empty all temporary caches, both RAM/HDD.  Unnecessary and rarely of use.
MAN {command}  ...  Lookup an in-script command in Lich's manual script.  `;man help' for more info.

    Starting Scripts:
EXEC {code}  .....  Quickscript. Run a whole line as a script: separate lines with ' ; '. Also 'e'.
EXECQ {code}  ....  Same as 'exec', but doesn't echo the 'active'/'finished' messages (q = quiet).
WIZ {script}  ....  Run a Wizard or StormFront formatted script; near-100% compatibility. Also 'w'.
WRAP {script}  ...  Wrap any interpreter's script (e.g. Perl, Python, etc.); see HELP WRAP for more.
FORCE {script}  ..  Bypass the 'already running' error and start another instance of a running script.
(ANYTHING ELSE)  .  If a line is unrecognized, it's interpreted as the script to run (abbrev. okay).

Any line sent to Lich must always begin with a '#{$clean_lich_char}' or it will be ignored (aliases are the only exception to this).

HELP
}

# Miscellaneous notes (part of the help documentation)
Hook.register(/^notes?$/i) { |str|
	respond("NOTES:")
	respond("- Just like every in-script command, aliases have full regular expression support (if you don't know what a 'Regular Expression' is, no need to trouble yourself with the details of what this means -- you can safely ignore it).")
	respond("")
	respond("- Lich supports passing a script command line arguments in the standard Wizard style (for example, '#{$clean_lich_char}ScriptName VariableOne VariableTwo \"Variable Three is all of these words, since they're in quotes\" etc').")
	respond("")
	respond("- You may abbreviate the name of the script you wish to launch, but the order of files could interfere (the first matching name found is launched). If this happens, use the full name.")
	respond("")
	respond("- With The Wizard option 'buffered screen updates' set to on, some scripts that 'echo' information can look like they're causing lag on some systems -- setting this option to 'off' will correct this.")
	respond("")
	respond("- For Wizard and StormFront scripts, Lich first checks its own directory. If a matching file isn't found, it attempts to find a match in the default Wizard installation directory. If it still can't find a matching name, it gives up and tells you it can't find the script.")
	respond("")
	respond("- You can enter 'reverse' as the first command line argument to execute a Wizard script in reverse; this will run a script from the end to the start instead of start to end, and will reverse all cardinal directions in 'move' commands (for instance, 'move up' is turned into 'move down', etc.). This only works on movement scripts w/o any label jumps, and since it can't reverse something like 'go crevice', you'll get stuck if the return-trip command isn't the same; use it accordingly.")
	respond("")
	respond("- Lich has no match limit whatsoever. This applies to both the Lich-script 'match' commands and the Wizard/StormFront-script 'match' commands (as well as 'matchre' in SF); if you either run a Wizard/SF script with Lich or use 'match' in a Lich script, you can use as many as you can tolerate typing.")
	respond("")
	respond("- You can start a script without having Lich announce that it's active by entering 'quiet' as the first command line argument, if you want to. For example, to start 'calcredux.lic' without cluttering your game window with the announcement, type '#{$clean_lich_char}calcredux quiet'.")
	respond("")
	respond("- Try not to use the '#{$clean_lich_char}force {scriptname}' command unnecessarily: it sounds a lot more useful than it really is, and a number of advanced scripts are built on the assumption that there's only going to be a single instance of that script executing at any given time (infomonitor.lic, for example, tends to short-circuit every running copy of itself when more than one is active at a time). Also, be extremely cautious with the 'force_start_script' command when using it inside a script; Lich has a great many different kinds of 'loops', and if you don't pay close attention, you may find that your script loops over the 'force_start_script' command and within a second or less has started thousands of copies of a single script -- which, by the way, Lich would be happy to do for you just before it effectively froze your computer while hogging the CPU to try and manage more scripts than your processor can deal with at once.  In the end it's little more than a major inconvenience, but it's possible that the operating system will become unstable and end up crashing in the process, so bear it in mind.")
	respond
	respond("- When executing a Wizard script, Lich is able to use a number of its handier features and still properly execute the script -- for example, Lich knows the difference between moving from one room to another and the 'look' output (not when run in SF, however); can usually recognize command-rejection due to type ahead, RT, stuns, webs, etc., and successfully execute the action when possible; will stand and repeat a rejected command if it's necessary, and various other random niceties.  Lich cannot, however, modify Wizard's (or StormFront's) highlight strings or other settings when running one of their scripts, and any such attempts will be silently ignored.")
	respond("")
	respond("- Since Lich by default places no restrictions on what a script can do, there is an optional 'safe mode' that you can run a script under. When run in safe mode, if a script tries to do something that might be unwanted (change the local system somehow, access files on the hard drive, make a connection to a remote computer, etc.), Lich will immediately abort execution of the script without performing whatever command looks suspicious (no questions asked, the script dies instantly) and notify you of what it was about to do. Note that this will disable a number of commands that could, in actuality, be totally harmless (basically it prevents MOST non-GemStone-specific functions from being usable, though some of the completely harmless functions Lich provides to scripts can still be used). Since it's impossible to tell whether something is malicious or just making proper use of Lich's features, a number of features commonly used by advanced scripts are disabled despite being totally harmless in a given context (scripts are not allowed to access the hard disk and therefore are unable to load/save settings, for example). To run a script this way, enter 'safe' as the first command line argument -- so to run calcredux in safe mode, you would type `#{$clean_lich_char}calcredux safe' (without the apostrophes of course).")
	respond("")
	respond("\034GSL") if !$stormfront
	respond("- Lich provides scripts with enormous power: if you don't completely trust the source of a given script, execute it in safe mode.  You should remember that when given free reign, Lich scripts can do a great many things that may be both very unwanted and very destructive.  Bear in mind that Ruby is a powerful high-level programming language, and unlike conventional scripting applications, Lich's scripts have the potential to be harmful and should not be run carelessly." + if !$stormfront then "\034GSM" else "" end)
	respond("")
}

# ABOUT
# Scroll the prog "about" info
Hook.register(/^about$/i) { |str|
	respond("--- The Lich Scripting Utility, v#{$version} ---\n  Author: Murray Miron (Shaelun in GemStone IV)\n  EMail: GS4Lich@yahoo.com\n  Project Website: http://lich.sudolife.com\n  AIM/Y! Screen Name: GS4Lich (I'm rarely on).\n\n  The Lich program is, in its most basic sense, a modified Ruby interpreter designed specifically for use with text-based MUDs.\n\n  Ruby is a high-level programming language that's very much like Perl and Python in the sense that they're all `interpreted' languages.  This means it isn't necessary to `compile' source code into 'program.exe' format, and that programs (which are often misleadingly referred to as `scripts') can be executed -- that is, `interpreted' -- directly from plain-text files.\n\n  Ruby itself was designed and developed primarily by Yukihiro Matsumoto ('Matz'), originated in Japan, and was released to the general public in 1995.")
}

# PURGE
# Purge the caches
Hook.register(/^purge$/i) { |str|
   Script.index.each { |ssock|
      ssock.clear
   }
   $_SERVERBUFFER_.dump
   $_SERVERBUFFER_.purge
   $_CLIENTBUFFER_.dump
   $_CLIENTBUFFER_.purge
   GC.start
	respond("--- Lich: memory and disk caches have been discarded.")
}

# WRAP
# External wrapper
Hook.register(/^wrap .+$/) { |str|
	if $LICHCONFIG['OS'] =~ /win/i or ENV['OS'] =~ /win/i
		respond "--- Lich: this command is only available in *NIX environments."
		return
	end
	cmdline = str.sub(/[^\s]+\s*/, '')
	fname = cmdline.slice(/[^\s]+/)
	begin
		f = File.open($script_dir + fname)
	rescue
		respond("--- Lich: #{$!}")
		return
	end
	iname = f.gets
	f.close
	if iname !~ /^#!/
		respond("--- Lich: script does not begin with `#!'  Read the help information.")
		return
	end
	iname = iname.sub(/^#!\s*/, '').strip
	unless File.exists? iname
		respond("--- Lich: interpreter #{iname} does not exist.")
		return
	end
	Script.wrap_script(fname, iname, cmdline.sub(/[^\s]+\s*/, ''))
}

# PAUSE ALL
# Pause all scripts
Hook.register(/^(?:pause all|pa)$/i) {
	if Script.index.empty?
		respond "--- Lich: no currently active scripts!"
	elsif (list = Script.index.find_all { |s| !s.paused }).empty?
		respond "--- Lich: all currently active scripts are already paused."
	elsif !list.find { |s| !s.no_pause }
		respond "--- Lich: all active scripts have toggled their `no_pause_all' values on.  Please pause them by name if desired."
	else
		list.each { |s| s.pause unless s.no_pause }
	end
}

# PAUSE
# Pause a script
Hook.register(/^(?:pause|p)(?! all)(?: [\d\w]+)?$/i) { |str|
	target = str.split[1].strip
	if Script.index.empty?
		respond "--- Lich: no scripts running!"
		return
	elsif !target or target.empty?
		target = Script.index.find_all { |s| !s.paused }.last
		unless target
			respond "--- Lich: all active scripts are already paused!"
			return
		end
	else
		unless target = Script.find(target)
			respond "--- Lich: #{str.split[1].strip} does not match any active script."
			return
		end
	end
	target.pause
}

# UNPAUSE ALL
# Unpause all scripts
Hook.register(/^(?:unpause all|upa|ua)$/i) {
	if Script.index.empty?
		respond "--- Lich: no currently active scripts!"
	elsif (list = Script.index.find_all { |s| s.paused }).empty?
		respond "--- Lich: there are no currently paused scripts to unpause!"
	else
		list.each { |s| s.unpause }
	end
}

# UNPAUSE
# Unpause a script
Hook.register(/^(?:unpause|up|u)(?! all)(?: [\d\w]+)?$/i) { |str|
	target = str.split[1].strip
	if Script.index.empty?
		respond "--- Lich: no scripts running!"
		return
	elsif !target or target.empty?
		target = Script.index.find_all { |s| s.paused }.last
		unless target
			respond "--- Lich: there are no currently paused scripts to unpause."
			return
		end
	else
		unless target = Script.find(target)
			respond "--- Lich: #{str.split[1].strip} does not match any active script."
			return
		end
	end
	target.unpause
}

# SENDCHAR
# Change the character that Lich displays to signify a script has sent something to the game
Hook.register(/^sendchar .$/) { |str|
	$SEND_CHARACTER = str[-1..-1]
	respond "--- Lich: script-sent data is now signified by the `#{$SEND_CHARACTER}' character.  As an example..."
	respond
	respond "[LichScript]#{$SEND_CHARACTER}look"
}

end
