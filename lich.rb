#####
# Copyright (C) 2005-2006 Murray Miron
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#	Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
#	Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
#	Neither the name of the organization nor the names of its contributors
# may be used to endorse or promote products derived from this software
# without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#####

##
# ...... Jesus this file is a mess.......
##


# Get the debug-mode STDERR redirection in place so there's a record of any errors (in Windows, the program has no STDOUT or STDERR)
if ARGV.find { |arg| arg =~ /^--debug$/ }
	$stderr = File.open('lich_debug.txt','a')
	$stdout = $stderr
	$stderr.sync = true
	$stdout.sync = true
	ARGV.delete_if { |arg| arg =~ /^--debug$/ }
elsif $LICHCONFIG['OS'] =~ /win/i
	$stderr = File.open('lich_debug.txt','w')
	$stdout = $stderr
	$stderr.sync = true
	$stdout.sync = true
end


$: << '.' << 'gui'
$:.uniq!

begin
	require "common.rb"
rescue
	$stderr.puts $!
rescue LoadError
	$stderr.puts $!
end


class NilClass
	def +(val)
		val
	end
	def closed?
		true
	end
	def method_missing(*args)
		nil
	end
end

if ARGV.find { |arg| arg =~ /^-h$|^--help$/ } then puts <<CLIHELP
Usage:  lich [OPTION]

Options are:
  -h, --help          Display this list.
  -V, --version       Display the program version number and credits.

  -d, --directory     Set the main Lich program directory (this run only).
      --script-dir    Define the directory Lich will search for script files in (this run only).  See example below.

  -s, --stormfront    Run in StormFront mode (this run only).  ip:port used by SF is storm.gs4.game.play.net:10024, stream encoding is XML-based
  -w, --wizard        Run in Wizard mode (this run only).  ip:port used by Wizard is gs3.simutronics.net:4900, stream encoding is GSL
      --dragonrealms  Run in Wizard mode for the DragonRealms game (this run only).
      --platinum      Platinum players connect to a different address than Prime players.  This tells Lich to catch the Platinum connection.
  -g, --game          Set the IP address and port of the game (this run only).  See example below.

  -c, --compressed    Do compression/decompression of the I/O data using Zlib (this is for MCCP, Mud Client Compression Protocol).
      --bare          Perform no data-scanning, just pass all game lines directly to scripts.  For maximizing efficiency w/ non-Simu MUDs.
      --debug         Mainly of use in Windows; redirects the program's STDERR & STDOUT to the '/lich_err.txt' file.
      --uninstall     Restore the hosts backup (and in Windows also launch the uninstall application).

The majority of Lich's built-in functionality was designed and implemented with Simutronics MUDs in mind (primarily Gemstone IV): as such, many options/features provided by Lich may not be applicable when it is used with a non-Simutronics MUD.  In nearly every aspect of the program, users who are not playing a Simutronics game should be aware that if the description of a feature/option does not sound applicable and/or compatible with the current game, it should be assumed that the feature/option is not.  This particularly applies to in-script methods (commands) that depend heavily on the data received from the game conforming to specific patterns (for instance, it's extremely unlikely Lich will know how much "health" your character has left in a non-Simutronics game, and so the "health" script command will most likely return a value of 0).

The level of increase in efficiency when Lich is run in "bare-bones mode" (i.e. started with the --bare argument) depends on the data stream received from a given game, but on average results in a moderate improvement and it's recommended that Lich be run this way for any game that does not send "status information" in a format consistent with Simutronics' GSL or XML encoding schemas.


Examples:
  lich -w -d /usr/bin/lich/          (run Lich in Wizard mode using the dir '/usr/bin/lich/' as the program's home)
  lich -g gs3.simutronics.net 4000   (run Lich using the IP address 'gs3.simutronics.net' and the port number '4000')
  lich --script-dir /mydir/scripts   (run Lich with its script directory set to '/mydir/scripts')
  lich --bare -g skotos.net 5555     (run in bare-bones mode with the IP address and port of the game set to 'skotos.net:5555')

CLIHELP
exit; end

if ARGV.find { |arg| arg =~ /^-(?i:V)$|^--version$/ } then $stdout.puts <<CLIVERSION
The Lich, version #{$version}
 (an implementation of the Ruby interpreter by Yukihiro Matsumoto designed to be a `script engine' for text-based MUDs)

- The Lich program and all material collectively referred to as "The Lich project" is copyright (C) 2005-2006 Murray Miron.
- The Gemstone IV and DragonRealms games are copyright (C) Simutronics Corporation.
- The Wizard front-end and the StormFront front-end are also copyrighted by the Simutronics Corporation.
- Ruby is (C) Yukihiro `Matz' Matsumoto.
- Inno Setup Compiler 5 is (C) 1997-2005 Jordan Russell (used for the Windows installation package).

Thanks to all those who've reported bugs and helped me track down problems on both Windows and Linux.
CLIVERSION
exit; end

if ARGV[1] and ARGV[1] !~ /^-/
	sal_fname = ARGV[1]
else
	sal_fname = nil
end

sock_keepalive_proc = proc { |sock|
	err_msg = proc { |err|
		err ||= $!
		$stderr.puts Time.now
		$stderr.puts err
		$stderr.puts err.backtrace
	}
	begin
		sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
	rescue
		err_msg.call($!)
	rescue Exception
		err_msg.call($!)
	end
}

trace_var(:$_CLIENT_, sock_keepalive_proc)
trace_var(:$_SERVER_, sock_keepalive_proc)

$LICHCONFIG.each_pair { |key, val| $LICHCONFIG[key] = File.expand_registry_str(val) }
Lich.reload_settings

# A few pages of repetitive checks to set things up for the current environment (operating system, program directories, front-end being used, etc.)
lich_dir = $lich_dir
if File.exists?(lich_dir + 'Scripts')
	script_dir = lich_dir + 'Scripts/'
elsif File.exists?(lich_dir + 'scripts')
	script_dir = lich_dir + 'scripts/'
else
	script_dir = lich_dir.dup
end

if tmplich_dir = ARGV.find { |val| val =~ /^-d$|^--directory$/ }
	lich_dir = ARGV[ARGV.index(tmplich_dir).succ]
	unless lich_dir[-1..-1] =~ /\\|\// then lich_dir += lich_dir.slice(/\\|\//) end
	if File.exists?(lich_dir + 'scripts') then script_dir = "#{lich_dir}scripts#{lich_dir.slice(/\\|\//)}" elsif File.exists?(lich_dir + 'Scripts') then script_dir = "#{lich_dir}Scripts#{lich_dir.slice(/\\|\//)}" else $stdout.puts("WARNING, no script directory found! The 'scripts' directory must be inside the Lich directory for things to function properly."); script_dir = "#{lich_dir}scripts#{lich_dir.slice(/\\|\//)}" end
	$stdout.puts("Lich directory set to #{lich_dir}")
end
$nix = false

if tmp = ARGV.find { |arg| arg =~ /^--launcher$/ }
	tmpidx = ARGV.index tmp
	ARGV.delete_at(tmpidx)
	estr = "$SAFE = 3\n" + ARGV[tmpidx..-1].join(" ")
	tmp = tmpidx = nil
	estr.taint
	simu_port = simu_ip = nil
	eval(estr, nil, "LauncherCode")
end
unless sal_fname
if ARGV.find { |arg| arg =~ /^-w$|^--wizard$/ }
	simu_port = 4900; simu_ip = 'gs3.simutronics.net'; $stormfront = false
elsif ARGV.find { |arg| arg =~ /^-s$|^--stormfront$/ }
	simu_port = 10024; simu_ip = "storm.gs4.game.play.net"; $stormfront = true
elsif gameinfoargv = ARGV.find { |arg| arg =~ /^-g$|^--game$/ }
	simu_ip = ARGV[ARGV.index(gameinfoargv) + 1]
	simu_port = ARGV[ARGV.index(gameinfoargv) + 2].to_i
	$stdout.puts("Game information being used:  #{simu_ip}:#{simu_port}"); $stdout.flush; $stormfront = false
elsif gameinfoargv = ARGV.find { |arg| arg =~ /^--platinum$/ }
	simu_ip = "gs-plat.simutronics.net"
	simu_port = 10121
elsif ARGV.find { |arg| arg =~ /^--dragonrealms$/i }
	simu_ip = 'dr.simutronics.net'; simu_port = 4901
elsif File.exists?("#{lich_dir}game.txt")
	file = File.open("#{lich_dir}game.txt"); data = file.readlines; file.close; file = nil
	data.delete_if { |line| line =~ /^\#/ }
	unless data.nil?
		simu_ip = data.shift.strip
		simu_port = data.shift.strip
		if data.first =~ /BARE/
			$BARE_BONES = true
		elsif data.first =~ /XML/
			$stormfront = true
		elsif data.first =~ /GSL/
			nil
		end
	end
elsif (File.exists?("#{lich_dir}stormfront-mode.txt") or File.exists?("#{lich_dir}stormfront-mode.txt.txt"))
	simu_port = 10024
	simu_ip = "storm.gs4.game.play.net"
	$stormfront = true
elsif File.exists?("#{lich_dir}dr-mode.txt")
	simu_port = 4901
	simu_ip = "dr.simutronics.net"
	$stormfront = false
elsif File.exists?(lich_dir + 'wizard-mode.txt')
	simu_port = 4900
	simu_ip = 'gs3.simutronics.net'
	$stormfront = false
elsif File.exists?('/Gse.~xt') or File.exists?(ENV['HOME'] + '/.wine/drive_c/Gse.~xt')
	begin
		print("No game/front-end input found, auto-detecting...")
		if File.exists?('/Gse.~xt')
			file = File.open('/Gse.~xt')
		else
			file = File.open(ENV['HOME'] + '/.wine/drive_c/Gse.~xt')
		end
		guessdata = file.readlines.collect { |line| line.strip }
		file.close
		file = nil
		simu_ip = guessdata.find { |line| line =~ /^GAMEHOST/ }.split('=').last.strip
		if simu_ip == '127.0.0.1'
			simu_ip = 'gs3.simutronics.net'
			simu_port = 4900
			print(" ...PsiNet alteration of file detected; configuring for Wizard.\n")
			$stormfront = false
		else
			simu_port = guessdata.find { |line| line =~ /^GAMEPORT/ }.split('=').last.strip.to_i
			fe = guessdata.find { |line| line =~ /^GAMEFILE/ }.split('=').last.strip
			if fe == 'WIZARD.EXE'
				print(" ...configuring for Wizard.\n")
				$stormfront = false
			else
				$stormfront = true
				print(" ...configuring for StormFront.\n")
			end
		end
	rescue
		$stderr.puts("Unrecoverable error during read of 'Gse.~xt' file! Falling back on defaults...")
		$stderr.puts($!)
		simu_port = 4900
		simu_ip = 'gs3.simutronics.net'
		$stormfront = false
	end
else
	simu_port = 4900
	simu_ip = "gs3.simutronics.net"
	$stormfront = false
end
else
	simu_port = nil
	simu_ip = nil
end

if ARGV.find { |arg| arg =~ /^--bare$/ }
	puts "Running in bare-bones mode."
	$BARE_BONES = true
end

puts(sprintf("IP:port = %s:%d", simu_ip, simu_port)) unless sal_fname

if set_sdir = ARGV.find { |arg| arg =~ /--script-dir/i }
	script_dir = ARGV[ARGV.index(set_sdir) + 1]
	script_dir[-1..-1] !~ /\/|\\/ ? script_dir = File.join(script_dir, '') : nil
	$stdout.puts("Script dir has been set to '#{script_dir}'."); $stdout.flush
end

if ARGV.find { |arg| arg =~ /^--?c(?:ompressed)$/i }
	$ZLIB_STREAM = true
	trace_var :$_SERVER_, proc { |server_socket|
		$_SERVER_ = ZlibStream.wrap(server_socket) if $ZLIB_STREAM
	}
	trace_var :$_CLIENT_, proc { |client_socket|
		$_CLIENT_ = ZlibStream.wrap(client_socket) if $ZLIB_STREAM
	}
else
	$ZLIB_STREAM = false
end

# Defining of various variables, GC.enable ensures that the garbage collector prevents us from needlessly using up system resources, etc..
log_dir = lich_dir
_TAGREGEXP_ = '^GSj|^GSg|^GSr|^GSm|^GSl|^GSZ|^GSY|^GSX|^GSn|^GSJ|^GSK|^GSq|^GSQ|^GSP|^GSa|^GSb'
_SFPARSEREGEXP_ = '<[^>]+>'
$SEND_CHARACTER = '>'
$_FAKE_STORMFRONT = false

$_SFPARSER_ = LichXML.new
$_SFPARSER_.extend(SFMetadata)

$lich_dir ||= lich_dir
$script_dir ||= script_dir
$data_dir ||= $lich_dir + "data" + File::SEPARATOR

$right_hand = String.new
$left_hand = String.new

$npcs = Array.new
$pcs = String.new
$roomarea = String.new
$roomtitle = String.new
$room_count = 0
$last_dir = String.new

$familiar_directions = String.new
$familiar_area = String.new
$familiar_room = String.new
$familiar_npcs = Array.new
$familiar_pcs = String.new

JUMP = Exception.exception('JUMP')
JUMP_ERROR = Exception.exception('JUMP_ERROR')

$_LICHERRCNT_ = 0
trace_var :$_LICHERRCNT_, proc { |n|
	if n >= 5
		begin
			$_SERVER_.close unless $_SERVER_.closed?
			$_CLIENT_.close unless $_CLIENT_.closed?
		rescue Exception
		rescue
		ensure
			exit
		end
	end
}

Socket.do_not_reverse_lookup = true
$_TA_BUFFER_ = []
$_SERVERBUFFER_ = CachedArray.new
$_CLIENTBUFFER_ = CachedArray.new

Dir.entries(CachedArray.dir).find_all { |f| f =~ /^\.cache[.\d]+/ }.each { |f|
	if (Time.now - File.mtime(File.join(CachedArray.dir, f))) > 3600
		File.delete(File.join(CachedArray.dir, f)) rescue()
	end
}

# Since there are so damn many places, this locates and returns the user's hosts file location
if $hosts_dir
	hosts_dir = File.expand_registry_str($hosts_dir)
	$hosts_dir = nil
else
	if ENV['windir']
		hosts_dir = find_hosts_file(ENV['windir'])
	elsif ENV['SYSTEMROOT']
		hosts_dir = find_hosts_file(ENV['SYSTEMROOT'])
	else
		hosts_dir = find_hosts_file
	end
end

if ARGV.find { |arg| arg =~ /--uninstall/ }
	$stdout.puts("Uninstalling...")
	uninsfile = Dir.entries(lich_dir).find_all { |file| file =~ /unins[0-9]+\.exe/i }.sort.last
	if File.exists?($lich_dir + "launcher-uninstall.dat")
		system("\"#{$lich_dir}" + "lichlauncher.exe\" -u")
	end
	if File.exists?(hosts_dir + 'hosts') and File.exists?($lich_dir + 'hosts.sav')
		if File.mtime(hosts_dir + "hosts") <= File.mtime($lich_dir + "hosts.sav")
			File.open($lich_dir + 'hosts.sav') { |savf|
				File.open(hosts_dir + 'hosts', 'w') { |hostf|
					hostf.write savf.read
				}
			}
		end
		exec(lich_dir + uninsfile) rescue()
		exit
	elsif File.exists?(hosts_dir + 'hosts')
		$stdout.puts("Restoration is unnecessary, launching uninstall application.")
		exec(lich_dir + uninsfile) rescue()
		exit
	else
		$stderr.puts("Cannot properly locate your hosts file or hosts backup file!  If they can't be found to restore them, it's nearly impossible that they were found to change in the first place.  Launching uninstall application.")
		exec(lich_dir + uninsfile) rescue()
		exit
	end
end

if hosts_dir.nil? and sal_fname.nil? then $stderr.puts("hosts_dir is nil (#{Time.now})"); exit(1) end

unless sal_fname
	simu_quad_ip = IPSocket.getaddress(simu_ip)
	begin
		listener = TCPServer.new("localhost", simu_port)
		begin
			listener.setsockopt(Socket::SOL_SOCKET,Socket::SO_REUSEADDR,1)
		rescue
			$stderr.puts("Error during setsockopt, aborting setting of SO_REUSEADDR: #{$!}")
		end
	rescue
		$temp_error ||= 0
		$temp_error += 1
		sleep 1
		retry unless $temp_error >= 30
		$stderr.puts("Lich cannot bind to the proper port, aborting execution.")
		exit!
	end
	$temp_error = nil
	hack_hosts(hosts_dir, simu_ip)
	if File.exists?("#{lich_dir}nosge.txt")
		nil
	elsif File.exists?("#{lich_dir}launch.txt")
		launch_sge_user(lich_dir)
	elsif ($LICHCONFIG['SGE Directory'] and File.exists? File.join($LICHCONFIG['SGE Directory'], 'Sge.exe')) or File.exists?("/Program Files/SIMU/SGE/Sge.exe")
		launch_sge_win(listener)
	elsif File.exists?("/home/fallen/.wine/drive_c/Program Files/SIMU/SGE/Sge.exe")
		launch_sge_nix(listener)
	elsif File.exists?("#{ENV['HOME']} + '/.wine/drive_c/Program Files/SIMU/SGE/Sge.exe")
		launch_sge_nix(listener)
	end
	timeout_thread = Thread.new { sleep 120 ; $stderr.puts("Timeout, restoring backup and exiting.") ; heal_hosts(hosts_dir); exit 1 }
	open_client(listener)
	timeout_thread.kill
	timeout_thread = nil
	Process.wait rescue()
	heal_hosts(hosts_dir)
else
	$stderr.puts "sal_fname == #{sal_fname}"
	begin
		sal_data = File.open(sal_fname) { |file| file.readlines }.collect { |line| line.chomp }
	rescue
		$stderr.puts "Error opening .sal (Simutronics Auto Launch) file: #{$!}"
		exit(1)
	end
	unless gameport = sal_data.find { |line| line =~ /GAMEPORT=/ }
			$stderr.puts ".sal file contains no GAMEPORT info"
			exit(1)
	end
	unless gamehost = sal_data.find { |opt| opt =~ /GAMEHOST=/ }
		$stderr.puts ".sal file contains no GAMEHOST info"
		exit(1)
	end
	unless game = sal_data.find { |opt| opt =~ /GAME=/ }
		$stderr.puts ".sal file contains no GAME info"
		exit(1)
	end
	gameport = gameport.split('=').last
	gamehost = gamehost.split('=').last
	game = game.split('=').last
	$stderr.puts sprintf("gamehost: %s   gameport: %s   game: %s", gamehost, gameport, game)
	begin
		listener = TCPServer.new("localhost", nil)
	rescue
		$stderr.puts "Cannot bind listening socket to local port: #{$!}"
		$stderr.puts sprintf("HOST: %s   PORT: %s   GAME: %s", gamehost, gameport, game)
		$stderr.puts sal_fname
		exit(1)
	end
	begin
		listener.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
	rescue
		$stderr.puts "Cannot set SO_REUSEADDR sockopt"
	end
	localport = listener.addr[1]
	mod_data = []
	sal_data.each { |sal_line| mod_data.push sal_line.sub(/GAMEPORT=.+/, "GAMEPORT=#{localport}").sub(/GAMEHOST=.+/, "GAMEHOST=localhost") }
	File.open($lich_dir + "lich.sal", "w") { |f| f.puts mod_data }
	if File.exists?($lich_dir + "autolaunch.txt")
		launch = File.open($lich_dir + 'autolaunch.txt') { |f| f.read.gsub(/[\r\n]/, '').strip }
		if launch.empty?
			Thread.new { system(File.join($LICHCONFIG['Launcher Directory'], "Launcher.exe #{$lich_dir + 'lich.sal'}")) }
		else
			Thread.new { system(launch + ' ' + File.join($lich_dir, "lich.sal")) }
		end
	elsif File.exists?($lich_dir + "launcher-uninstall.dat")
		launch = File.open($lich_dir + "launcher-uninstall.dat")
		prog = launch.readlines.first.chomp
		launch.close
		Thread.new { system(prog.sub("%1", File.join($lich_dir.gsub("/", "\\"), "lich.sal"))) }
	else
		Thread.new { system(File.join($LICHCONFIG['Launcher Directory'], "Launcher.exe " + $lich_dir.gsub("/", "\\") + "lich.sal")) }
	end
	timeout_thr = Thread.new {
		sleep 15
		$stderr.puts "timeout waiting for connection."
		exit(1)
	}
	$_CLIENT_ = listener.accept
	begin
		timeout_thr.kill
		listener.close
	rescue
		$stderr.puts $!
	end
	$_SERVER_ = TCPSocket.open(gamehost, gameport)
	if game =~ /STORM/i
		$stormfront = true
	end
end



unless ENV['OS'] =~ /win/i
	begin
		Process.uid = `id -ru`.strip.to_i
		Process.gid = `id -rg`.strip.to_i
		Process.egid = `id -rg`.strip.to_i
		Process.euid = `id -ru`.strip.to_i
	rescue SecurityError
		$stderr.puts "Error dropping superuser privileges: #{$!}"
	rescue SystemCallError
		$stderr.puts "Error dropping superuser privileges: #{$!}"
	rescue
		$stderr.puts "Error dropping superuser privileges: #{$!}"
	end
end

Dir.mkdir($data_dir) rescue()

errtimeout = 1
# We've connected with the game client... so shutdown the listening socket (open it up for use by other progs, etc.)
begin
# Somehow... for some ridiculous reason... Windows doesn't let us close the socket if we shut it down first...
# listener.shutdown
	listener.close unless listener.closed?
rescue
	$stderr.puts("error closing listener socket: #{$!}")
	errtimeout += 1
	if errtimeout > 20 then $stderr.puts("error appears unrecoverable, aborting") end
	sleep 0.05
	retry unless errtimeout > 20
end

if ARGV.find { |arg| arg =~ /^--test|^-t/ }
	$_SERVER_ = $stdin
	$_CLIENT_.puts "Running in test mode: host socket set to stdin."
elsif !$_SERVER_
	open_gs(simu_quad_ip, simu_port)
end

errtimeout = nil
listener = timeout_thr = nil

def show_favs(who=nil)
	begin
		file = File.open("#{$lich_dir}favorites.txt"); fav_data = file.readlines; file.close; file = nil
		if who.nil?
			favs_all = fav_data.find_all { |line| line =~ /^ALL:/ } ; favs_all.each_with_index { |scr,idx| favs_all[idx] = scr.sub('ALL:','') }
			favs_char = fav_data.find_all { |line| line =~ /^#{checkname}:/ } ; favs_char.each_with_index { |scr,idx| favs_char[idx] = scr.sub((checkname + ':'),'') }
		elsif who == 'all'
			fav_list = fav_data.sort_by { |name| name.split(':').first }
			respond("Favorites for All Characters:")
			respond(fav_list)
			return
		end
	rescue
		fav_data = [ "none" ]
		favs_all = [ 'none' ]
		favs_char = [ 'none' ]
	end
		if fav_data.empty? or fav_data.nil?
			fav_list = "none"
		else
			fav_list_all = favs_all.join(', ').gsub(/\r|\n/,'')
			fav_list_char = favs_char.join(', ').gsub(/\r|\n/,'')
		end
		respond("Global Favorites (apply to all chars):  #{fav_list_all}.") unless favs_all.empty?
		respond("Favorites for Character #{checkname}:  #{fav_list_char}.") unless favs_char.empty?
end

if File.exists?("#{lich_dir}lich-char.txt")
	file = File.open("#{lich_dir}lich-char.txt"); arr = file.readlines; arr = arr.find_all { |line| line !~ /^#/ }; $clean_lich_char = arr.last.strip; file.close; file = nil
else
	$clean_lich_char = ';'
end
lich_char = Regexp.escape("#{$clean_lich_char}")

undef :exit!

client_thread = Thread.new {
$login_time = Time.now
alias_failed = false
aliasarray = Array.new
if File.exists?(lich_dir + 'aliases.txt')
	file = File.open(lich_dir + 'aliases.txt', 'rb')
	newfile = File.open($data_dir + 'aliases.dat', 'wb')
	newfile.write(file.read)
	file.close
	newfile.close
	file = nil
	newfile = nil
	File.delete(lich_dir + 'aliases.txt')
	GC.start
end
begin
	if File.exists?(lich_dir + 'aliases.dat')
		File.rename(lich_dir + 'aliases.dat', $data_dir + 'aliases.dat')
	end
	file = File.open($data_dir + 'aliases.dat', 'rb'); alias_list_hash = Marshal.load(file.read); file.close; file = nil
	alias_list = alias_list_hash.keys.dup
rescue
	alias_list_hash = Hash.new
	alias_list = Array.new
	file = File.open($data_dir + 'aliases.dat','wb'); file.write(Marshal.dump(alias_list_hash)); file.close; file = nil
	alias_failed = true unless alias_failed
	retry unless alias_failed
end
aliasregexp = alias_list.join('|^(?:<c>)?')
running_alias = false
if File.exists?(lich_dir + "spellshorts.txt")
	dospellshorts = true
else
	dospellshorts = false
end
if !($stormfront or $_FAKE_STORMFRONT) and File.exists?(lich_dir + "ta_limit.txt")
	file = File.open(lich_dir + "ta_limit.txt")
	$TALIMIT = file.readlines.find_all { |line| line !~ /^#/ }.join.slice(/\d+/).to_i
	file.close
	file = nil
else
	$TALIMIT = 0
end
2.times {
	client_string = $_CLIENT_.gets
	$_CLIENTBUFFER_.push(client_string.dup)
	$_SERVER_.write(client_string)
}
until $_CLIENT_.closed? or $_SERVER_.closed?

#init_hooks
#undef :init_hooks

begin

if defined?(Hook) and not defined?(UpstreamHook)
	UpstreamHook = Hook
else
	class UpstreamHook
		def UpstreamHook.method_missing(*args)
			false
		end
	end
end

while client_string = $_CLIENT_.gets
	$_IDLETIMESTAMP_ = Time.now
	if dospellshorts and (spellshort = /^\s*(\d\d\d\d?)(.*)?$/.match(client_string.chomp))
		if !spellshort.captures[1].empty?
			$stormfront ? $_SERVER_.send("<c>prep #{spellshort.captures[0]}\n", 0) : $_SERVER_.send("prep #{spellshort.captures[0]}\n", 0)
			$stormfront ? $_SERVER_.send("<c>cast at #{spellshort.captures[1].strip}\n", 0) : $_SERVER_.send("cast at #{spellshort.captures[1].strip}\n", 0)
		else
			$stormfront ? $_SERVER_.send("<c>incant #{spellshort.captures[0]}\n", 0) : $_SERVER_.send("incant #{spellshort.captures[0]}\n", 0)
		end
		next
	end
	if client_string =~ /^(?:<c>)?#{lich_char}/o and (client_string !~ /^(?:<c>)?(#{aliasregexp})\b([^\r\n]+)?$/ or client_string =~ /^(?:<c>)?#{lich_char}alias\b/i)
		client_string = client_string.sub(/#{lich_char}/o, ';')
		cmd = $'.chomp.downcase
		if cmd =~ /^\!/
			cleaned_psi_string = client_string.sub(/^;\!/, ';').chomp
			$_SERVER_.puts(cleaned_psi_string)
			$_CLIENTBUFFER_.push(cleaned_psi_string)
			respond("--- Lich: saw the '!' (ignore this) signal. Sent: '#{cleaned_psi_string}'.")
		elsif UpstreamHook.call(cmd)
			next
		elsif cmd =~ /^spellshorts?$/i
			dospellshorts = !dospellshorts
			respond "--- Lich: spellshorts are now %s." % (dospellshorts ? "on" : "off")
			if dospellshorts
				File.open($lich_dir + "spellshorts.txt", "w") { |f| f.puts } rescue()
			else
				File.unlink($lich_dir + "spellshorts.txt") rescue()
			end
			next
		elsif cmd.empty?
			respond("--- Lich: saw no data in the Lich-command string -- ignoring!")
		elsif cmd =~ /^list$|^l$/
			unless Script.index.empty? then respond("--- Lich: #{Script.index.join(", ")}.") else respond("--- Lich: no active scripts.") end
			respond("--- Lich: 'Watchfors' active are #{Watchfor.list}.") if Watchfor.any?
		elsif cmd =~ /^debug$/
			$LICH_DEBUG = !$LICH_DEBUG
			if $LICH_DEBUG
				respond("--- Lich: debugging information will now be shown for scripts.")
			else
				respond("--- Lich: debugging information will no longer be shown for scripts.")
			end
		elsif eobj = /^(?:exec|e)(q)? .+/.match(cmd)
			Thread.new {
				cmd_data = "execscript.set_as_good\n#{client_string.sub(/^(?:<c>;|;)(?:exec|execq|e|eq) /i, '')}"
				Thread.current.priority = 0
				begin
					if eobj.captures.first.nil? then execscript = Script.new('exec') else execscript = Script.new('exec',['quiet']) end
					eval(cmd_data, nil, execscript.name.to_s, -1)
					respond("--- Lich: #{execscript.name} has finished.") unless execscript.quiet
					execscript.kill
				rescue SyntaxError
					respond("--- Lich SyntaxError: #{$!}")
					respond("--- Lich: #{execscript.name} has exited.")
					execscript.kill
				rescue SystemExit
					respond("--- Lich: #{execscript.name} has exited.") unless execscript.quiet
					execscript.kill
				rescue SecurityError
					respond("--- Lich SecurityError: #{$!}")
					respond("--- Lich: #{execscript.name} has exited.")
					execscript.kill
				rescue ThreadError
					respond("--- Lich ThreadError: #{$!}")
					respond("--- Lich: #{execscript.name} has exited.")
					execscript.kill
				rescue Exception
					respond("--- Exception: #{$!}")
					respond("--- Lich: #{execscript.name} has exited.")
					execscript.kill
				rescue ScriptError
					respond("--- ScriptError: #{$!}")
					respond("--- Lich: #{execscript.name} has exited.")
					execscript.kill
				rescue
					respond("--- Lich Error: #{$!}")
					respond("--- Lich: #{execscript.name} has exited.")
					execscript.kill
				end
				Script.thread_hash.delete(Thread.current.group)
			}
		elsif cmd =~ /^kill$|^stop$|^k$/
			if Script.index.empty?
				respond("--- Lich: no scripts running!")
			else
				respond("--- Lich: #{Script.index.last.kill} stopped.")
			end
		elsif cmd =~ /^kill all$|^stop all$|^ka$/
			wf = Watchfor.any?
			if Script.index.empty?
				unless wf
					respond("--- Lich: no scripts running!")
				else
					Watchfor.untrace_all(true)
					respond("--- Lich: all 'Watchfors' have been killed.")
				end
			else
				if (Script.index.find_all { |val| !val.no_ka }.empty?)
					respond("--- Lich: all currently running scripts have set the 'no kill all' option! Kill them individually.")
					next
				else
					Watchfor.untrace_all(true)
					Script.index.find_all { |ikeelu| !ikeelu.no_ka }.each { |ikeelu| ikeelu.kill }
				end
				list = Script.index.find_all { |scr| scr.no_ka }.collect { |scr| scr.name }
				if wf
					if list.empty?
						respond("--- Lich: all 'Watchfors' and all running scripts have been stopped.")
					else	
						respond("--- Lich: all 'Watchfors' and all scripts except #{list.join(', ')} have been stopped.")
					end
				else
					if list.empty?
						respond("--- Lich: all scripts have been stopped.")
					else
						respond("--- Lich: all scripts except #{list.join(', ')} have been stopped.")
					end
				end
			end
			list.clear
			list = nil
			GC.start
		elsif cmd =~ /^k\s.+|^stop\s.+|^kill\s.+/
			target_name = client_string.sub('<c>', '').sub(/^;k\s|^;s\s|^;stop\s|^;kill\s/i, '').chomp
			if (condemned = Script.index.find { |s_sock| s_sock.name == target_name }).nil?
				condemned = Script.index.find { |s_sock| s_sock.name =~ /^#{target_name}/i }
			end
			if condemned.nil?
				respond("--- Lich: #{target_name}.lic does not appear to be running! Use ';list' to see what's active.")
			else
				name = condemned.kill
				respond("--- Lich: #{name} stopped.")
			end
			GC.start
		elsif cmd == "log"
			dump_to_log(log_dir)
		elsif cmd =~ /^chat .+|^,.+|^who(?: \w+)?$|^(\w+):.+|^(admin) .+|^locate \w+$|^info \w+$|^skills \w+$|^spells \w+$|^health \w+$/
			namen = $1.dup
			if $2 == "admin"
				adminaction = $'.dup
				if (tgt = Script.index.find { |scr| scr.name =~ /lichnet/i })
					tgt.unique_puts(client_string.sub(/^(?:<c>)?;/,''))
				else
					respond("--- Lich: the LichNet client script must be running in order to talk to the LichNet server!")
				end
				tgt = nil
			elsif (tgt = Script.index.find { |scr| scr.name =~ /lichnet/i })
				if !namen.nil?
					tgt.unique_puts(client_string.sub(/^(?:<c>;|;)[^:]+:/,"to #{namen} "))
				else
					tgt.unique_puts(client_string.sub(/^(?:<c>;|;)(?:chat|,)?/i,'').sub(/^\s*(locate|info|skills|spells|health) (\w+)$/i, '::\1::\2'))
				end
			else
				respond("--- Lich: the LichNet client script must be running in order to talk to the LichNet server!")
			end
			tgt = nil
		elsif cmd =~ /^(?:tunein|tuneout)$/i
			if tgt = Script.index.find { |scr| scr.name =~ /lichnet/i }
				tgt.unique_puts "::#{cmd}::"
			else
				respond("--- Lich: the LichNet client script must be running in order to talk to the LichNet server!")
			end
			tgt = nil
		elsif cmd =~ /^send |^s /
			$_CLIENTBUFFER_.pop
			if cmd.split[1] == "to"
				tgt = Script.index.find { |fscr| fscr.name == cmd.split[2].chomp.strip }
				if tgt.nil?
					tgt = Script.index.find { |fscr| fscr.name =~ /^#{cmd.split[2].chomp.strip}/i }
				end
				if tgt.nil? then respond("--- Lich: '#{cmd.split[2].chomp.strip}' does not match any active script!") ; next end
				msg = client_string.sub(/^(?:<c>;|;)(?:[Ss]|[Ss][Ee][Nn][Dd])\s[Tt][Oo]\s#{cmd.split[2]}\s/, '').chomp
				if tgt.unique
					tgt.unique_puts(msg)
					respond("--- Lich: sent to '#{tgt}' ('unique' stack): #{msg}")
				else
					tgt.puts(msg)
					respond("--- Lich: sent to '#{tgt}': #{msg}")
				end
				tgt = nil
			else
				message = client_string.sub(/(?:<c>;|;)(?:[Ss]|[Ss][Ee][Nn][Dd]) /, '')
				if Script.index.empty? then respond("--- No active scripts to send to!") ; next end
				respond("--- Sent: #{message}")
				Script.namescript_incoming(message)
			end
		elsif cmd == "reload"
			Lich.reload_settings
			begin
				file = File.open($data_dir + 'aliases.dat', 'rb'); alias_list_hash = Marshal.load(file.read); file.close; file = nil
				alias_list = alias_list_hash.keys.dup
			rescue
				file = File.open($data_dir + 'aliases.dat', 'wb'); file.write(Marshal.dump(Hash.new)); file.close; file = nil
				retry
			end
			respond("--- Lich: settings have been reloaded from your 'settings.txt' and 'aliases.dat' files.")
		elsif cmd =~ /^fave?s add\s.+/
			$_CLIENTBUFFER_.pop
			if client_string.split[2] =~ /all/i
				add = client_string.sub('<c>', '').sub(/\;fave?s add all /i, '').chomp
				tgt = 'ALL:'
			else
				add = client_string.sub('<c>', '').sub(/\;fave?s add /i, '').chomp
				tgt = "#{checkname}:"
			end
			begin
			  file = File.open("#{lich_dir}favorites.txt"); fav_data = file.readlines; file.close; file = nil
			  fav_data.compact!
			  list = Dir.entries($script_dir)
			  unless list.find { |sname| sname =~ /^#{add}\.lic/i }
				add = list.find { |sname| sname =~ /^#{add}.*\.lic/i }
				unless add.nil? then add.sub!(/\.lic$/i,'') end
			  end
			  fav_data.push(tgt + add) unless add.nil?
			  file = File.open("#{lich_dir}favorites.txt", "w"); file.puts(fav_data); file.close; file = nil
			rescue SystemCallError
			  file = File.open("#{lich_dir}favorites.txt", "w"); file.puts(tgt + add); file.close; file = nil
			rescue
			  respond("--- Lich: unrecoverable error encountered, aborting preferences update: #{$!}")
			end
			show_favs
			tgt = nil
		elsif cmd =~ /^fave?s del(?:ete)?\s.+/
			$_CLIENTBUFFER_.pop
			if client_string.split[2] =~ /all/i
				del = client_string.sub('<c>', '').sub(/^\;fave?s del(?:ete)? all /i, "").chomp
				tgt = 'all'
			else
				del = client_string.sub('<c>','').sub(/^\;fave?s del(?:ete)? /i,'').chomp
				tgt = "#{checkname}"
			end
			begin
			  file = File.open("#{lich_dir}favorites.txt"); fav_data = file.readlines; file.close; file = nil
			  fav_data.delete_if { |line| line =~ /^#{tgt}:#{del}/i }
			  fav_data.compact!
			  file = File.open("#{lich_dir}favorites.txt", "w"); file.puts(fav_data); file.close; file = nil
			rescue
			  respond("--- Lich: unrecoverable error encountered, aborting preferences update: #{$!}")
			end
			show_favs
			tgt = nil
		elsif cmd =~ /^(?:fave?s|fave?s all)$/
			$_CLIENTBUFFER_.pop
			if cmd.split.length == 1 then show_favs else show_favs('all') end
		elsif cmd =~ /^fave?s load$/
			$_CLIENTBUFFER_.pop
			begin
				respond("\r\n--- Lich: started #{(load_favs(lich_dir,script_dir,true).join(', '))}.\r\n")
			rescue
				respond; respond("Fatal error loading favs list: #{$!}"); respond
			end
		elsif cmd == "stats"
		  begin
		  	t_struct = Process.times
			ramsz = 0
			ObjectSpace.each_object(Script) { |scr| ramsz += (scr.io.length + scr.unique_io.length + scr.upstream_io.length + 12) }
			if File.exists? $_SERVERBUFFER_.getfd
				sbufsz = File.size($_SERVERBUFFER_.getfd)
			else
				sbufsz = 0
			end
			if File.exists? $_CLIENTBUFFER_.getfd
				pbufsz = File.size($_CLIENTBUFFER_.getfd)
			else
				pbufsz = 0
			end
			fary = []
			ary = []
			ObjectSpace.each_object(File) { |f| fary.push f.path if !f.closed? }
			ObjectSpace.each_object(Script) { |s| ary.push s.name unless Script.find(s.name) }
			respond
			respond sprintf("Time passed since login:         %s", ((Time.now.to_f - $login_time.to_f) / 60.00).as_time)
			respond sprintf("System CPU time used (secs):     %f", t_struct.stime)
			respond sprintf("User CPU time used (secs):       %f", t_struct.utime)
			respond sprintf("Lich's process ID:               %d", Process.pid)
			echo
			respond sprintf("Lich's `home' directory is:      %s", $lich_dir)
			respond sprintf("Lich's `saved data' dir is:      %s", $data_dir)
			respond sprintf("Lich's script directory is:      %s", $script_dir)
			respond sprintf("Wizard script directory is:      %s", File.join($LICHCONFIG['Wizard Directory'], "Scripts")) if $LICHCONFIG['Wizard Directory']
			respond sprintf("# of room transitions counted:   %d%s", $room_count - 1, ($stormfront ? " (not accurate when using SF)" : ""))
			echo
			respond sprintf("Size of temporary disk caches:   %.3fKB", (sbufsz + pbufsz) / 1024.0)
			respond sprintf("RAM in use by script IO buffers: %.3fKB", ramsz / 1024.0)
			respond sprintf("# of dead scripts still on heap: %d%s", ary.length, (ary.empty? ? "" : " (#{ary.join(', ')})"))
			respond sprintf("# of open file descriptors:      %d%s", fary.length, (fary.empty? ? "" : " (#{fary.join(', ')})"))
			echo
			respond sprintf("# of scripts in scheduling pool: %d", Script.index.length)
			ary = Script.index.reject { |s| Script.wakelist.include? s }
			respond sprintf("# of scripts queued to execute:  %d%s", ary.length, (ary.empty? ? "" : " (#{ary.join(', ')})"))
			respond sprintf("# of scripts blocked on IO:      %d%s", Script.wakeme.length, (Script.wakeme.empty? ? "" : " (#{Script.wakeme.collect { |thr| Script.index.find { |s| s.threads.list.include? thr } }.compact.join(', ')})"))
			ary = fary = nil
		  rescue
		  	respond("--- Lich: an error while checking settings has occurred: #{$!}")
		  end
		elsif cmd == "repeat notice"
			show_notice
		elsif cmd =~ /^alias(?:es)?( add | add| set | set| help| del )?([^=]+)?(?:\=)?(.+)?$/
			begin
			if $1.nil?
				if alias_list_hash.empty?
					respond("")
					respond("--- You currently have no Lich aliases.")
					respond("")
				else
					respond("--- Your current Lich aliases are:\r\n")
					tn = '0'
					alias_list.sort.each { |akakey| respond(tn.succ! + ') ' + akakey.upcase + " => " + alias_list_hash[akakey])}
				end
			elsif ($1 == " add ") || ($1 == " add") || ($1 == " set ") || ($1 == " set") || ($1 == " help")
				if ($2.nil? || $3.nil?)
					respond("- Syntax for alias setting is `;alias set [what you will type]=[what will be sent]'.")
					respond("- Syntax for alias deleting is `;alias del [which alias to delete]'.")
					respond("- Separate lines with `\\r'; ex:  ;alias set telloff='I hate you!\\r'Go away!")
					respond("- You can also use `\\?', and Lich will replace it with whatever came after the alias.")
					respond("- `add' is a synonym for 'set'. Also, Lich will properly recognize aliased commands; e.g.:")
					respond(" `;alias set startup=;test\\r;echo\\r;calcredux' would start scripts test, echo, & calcredux.")
					next
				end
				hkey = $2.to_s.chomp
				hval = client_string.sub(/[^=]+=\s*/, '')
				alias_list_hash[hkey] = hval
				file = File.open($data_dir + 'aliases.dat','wb'); file.write(Marshal.dump(alias_list_hash)); file.close; file = nil
				alias_list = alias_list_hash.keys.dup
				aliasregexp = alias_list.join('|^(?:<c>)?')
				respond("--- Alias `#{hkey.chomp}' => `#{hval.chomp}' added.")
				next
			elsif $1 == " del "
				if $2.nil?
					respond("- Syntax for alias setting is `;alias set [what you will type]=[what will be sent]'.")
					respond("- Syntax for alias deleting is `;alias del [which alias to delete]'.")
					respond("- Separate lines with `\\r'; ex:  ;alias set telloff='I hate you!\\r'Go away!")
					respond("- You can also use `\\?', and Lich will replace it with whatever came after the alias.")
					respond("- `add' is a synonym for `set'. Also, Lich will properly recognize aliased commands; e.g.:")
					respond(" `;alias set startup=;test\\r;echo\\r;calcredux' would start scripts test, echo, & calcredux.")
					next
				end
				delalias = $2.dup
				if (agone = alias_list_hash.keys.find { |akey| akey =~ /^#{Regexp.escape(delalias)}$/})
					vgone = alias_list_hash.delete(agone)
				elsif (agone = alias_list_hash.keys.find { |akey| akey =~ /^#{Regexp.escape(delalias)}/i })
					vgone = alias_list_hash.delete(agone)
				else
					respond("--- Alias `#{delalias}' was not found!")
					next
				end
				file = File.open($data_dir + 'aliases.dat','wb'); file.write(Marshal.dump(alias_list_hash)); file.close; file = nil
				alias_list = alias_list_hash.keys.dup
				aliasregexp = alias_list.join('|^(?:<c>)?')
				respond("--- Alias `#{agone.chomp}' => '#{vgone.chomp}' removed.")
			end
			rescue
				respond "--- Lich: unrecoverable error modifying aliases: #{$!}"
			end
		elsif cmd =~ /^magic\s?(?:clear|set|set .+|reset|help|details|enable|disable)?\s?(?:[^\s]+)?\s?(?:[0-9]+)?$/
			if (infomon = Script.index.find { |val| val.name == 'infomonitor' })
				infomon.puts(cmd)
				infomon = nil
			else
				respond("--- Lich: the `infomonitor.lic' script must be running to do this!")
			end
		elsif cmd =~ /^wiz .+|^w .+/
		  begin
			new_script = Regexp.escape(client_string.split[1]); client_string.sub!(/^(?:<c>)?;?(?i:wiz|w)(?:\s+[^\s]+)?(?:\s+)?/,'')
			start_wizard_script(new_script,client_string.scan(/"[^"]+"|[^"\s]+/))
		  rescue
		  	respond("--- Lich: #{$!}")
		  end
		elsif cmd =~ /^force .+/
			new_script = Regexp.escape(client_string.sub(/^<c>;force |^;force /i, '').split.first.chomp)
			if File.exists?(script_dir.to_s + "#{new_script}.lic")
				start_script(script_dir.to_s + "#{new_script}.lic",client_string.sub(/^(?:<c>;|;)(?i:force )#{new_script}\s?/i, '').scan(/"[^"]+"|[^"\s]+/).collect { |val| val.gsub(/(?!\\)?"/,'') })
			else
				s_files = Dir.entries(script_dir)[2..-1]
				if fname = s_files.find { |val| val =~ /^#{new_script}.+\.(?i:lic|rbw?|cmd|gz)(?:gz)?$/ }
					start_script(script_dir.to_s + fname.to_s,client_string.sub(/^(?:<c>;|;)(?:force )#{new_script}\s?/i, '').scan(/"[^"]+"|[^"\s]+/).collect { |val| val.gsub(/(?!\\)?"/,'') })
				else
					respond("--- Lich: could not find script `#{new_script}' in directory #{script_dir}!")
					next
				end
			end
		elsif cmd =~ /^(?:ta|typeahead)(?: help| \d)?$/i
			if cmd.include?('help') or !cmd.slice(/\d+/)
				respond "--- Lich: This allows you to set your typeahead line limit threshold when you use The Wizard (this feature does not apply to StormFront).  This option, when enabled, tells Lich how many typeahead lines the game will allow you to send -- if you try to send more lines than this number before the game has responded to what you've already sent, Lich will 'buffer' the commands and won't send them until the game will accept them (instead of rejecting them because of your type ahead limit).  This effectively gives you an infinite number of typeahead lines.  To disable this option, simply set your typeahead threshold to 0 by typing `;ta 0'.  To enable it again, set your threshold to however many lines your Simutronics account is allowed.  Basic subscribers -- like me -- are allowed 1 type ahead line, so to enable this feature you'd type `;ta 2' to tell Lich that if you send more than 2 commands to the game before it's responded, that it should buffer any further ones and send them as the game responds to what it's already sent." if cmd.include?('help')
				respond "Your current typeahead limit threshold is #{$TALIMIT}."
			elsif newnum = cmd.slice(/\d+/)
				$TALIMIT = newnum.to_i
				if $TALIMIT.zero?
					respond "--- Lich: Type ahead compensation has been disabled."
				else
					respond "--- Lich: Your typeahead limit threshold has been set to #{$TALIMIT}."
				end
				begin
					file = File.open(lich_dir + "ta_limit.txt", "w")
					file.puts newnum
					file.close
				rescue
					respond "--- Unknown error while trying to save the updated TA limit to disk: #{$!}"
				end
			end
		elsif cmd =~ /^(?:tac|ta clear|typeahead clear)$/i
			$_TA_BUFFER_.clear
			$TA_waiting_on_resp = 0
			respond "--- Lich: current typeahead buffer has been discarded."
		else
			new_script = Regexp.escape(client_string.sub(/^<c>;|^;/, '').split.first.chomp)
			if File.exists?(script_dir.to_s + "#{new_script}.lic")
				if alrdy_name = Script.index.find { |running| running.name.sub(/ \(paused\)$/,'') == new_script }
					respond("--- Lich: #{alrdy_name.name.sub(/ \(paused\)$/,'')} is already running (use #{$clean_lich_char}force [ScriptName] if desired).")
					next
				end
				start_script(script_dir.to_s + "#{new_script}.lic",client_string.sub(/^(?:<c>;|;)#{new_script}\s?/, '').scan(/"[^"]+"|[^"\s]+/).collect { |val| val.gsub(/(?!\\)?"/,'') })
			else
				s_files = Dir.entries(script_dir)[2..-1]
				if fname = s_files.find { |val| val =~ /^#{new_script}\.(?:lic|rbw?)(?:\.gz|\.Z)?$/i } ||
					s_files.find { |val| val =~ /^#{new_script}[^.]+\.(?i:lic|rbw?)(?:\.gz|\.Z)?$/ } ||
					s_files.find { |val| val =~ /^#{new_script}[^.]+\.(?:lic|rbw?)(?:\.gz|\.Z)?$/i } ||
					s_files.find { |val| val =~ /^#{new_script}$/i }
					s_files = nil
					if alrdy_name = Script.index.find { |running| running.name.sub(/ \(paused\)$/,'') == fname.gsub(/\.(?:lic|rbw?|gz|Z)(?:gz|Z)?/i,'') }
						respond("--- Lich: #{alrdy_name.name.sub(/ \(paused\)$/,'')} is already running (use #{$clean_lich_char}force [ScriptName] if desired).")
						next
					end
					start_script(script_dir.to_s + fname.to_s,client_string.sub(/^(?:<c>;|;)#{new_script}\s?/, '').scan(/"[^"]+"|[^"\s]+/).collect { |val| val.gsub(/(?!\\)?"/,'') })
				else
					respond "--- Lich: unable to find a matching script, trying to load it as a Wizard .cmd file (toggle debug off to get rid of this notice)..." if $LICH_DEBUG
					client_string = ";wiz #{client_string[1..-1]}"
					redo
					respond("--- Lich: could not find script `#{new_script}' in directory #{script_dir}!")
					s_files = nil
					next
				end
			end
		end
	elsif (!running_alias and client_string =~ /^(?:<c>)?(#{aliasregexp})\b([^\r\n]+)?$/ and !aliasregexp.empty?)
	  if client_string == "\n" then ($_SERVER_.write("\n") ; next) end
	  begin
			if $2.nil? then aliastarget = String.new else aliastarget = $2.dup end
			aliased = alias_list_hash[$2].dup
			if aliased.nil?
				aliaskey = alias_list_hash.keys.find { |key| client_string.chomp.sub(/^<c>/,'').sub(/#{Regexp.escape(aliastarget)}/,'') =~ /#{key}/ }
				aliased = alias_list_hash[aliaskey].dup
			end
		if aliased.nil? then respond("--- Alias error: recognized the command as being an alias, but couldn't identify which one!") ; next end
		if aliased.include?('\?')
			aliased.gsub!('\?',aliastarget)
		else
			aliased.concat(aliastarget)
		end
		$_CLIENTBUFFER_.push((client_string.chomp + '=>' + aliased))
		aliasarray = aliased.split('\r') ; aliasarray.each_with_index { |val,idx| aliasarray[idx] = (val.chomp + "\n") }
		client_string = aliasarray.shift
		running_alias = true
		redo
	  rescue
	  	respond("--- Lich: alias error: #{$!}")
	  end
	else
		if $TALIMIT.nil?
			$TALIMIT = 0
		end
	  begin
	  	if $TALIMIT == 0
			$_SERVER_.puts client_string
		elsif client_string.strip.empty?
			next
	  	elsif $TA_waiting_on_resp >= $TALIMIT
		  	ta_cmd = client_string.dup
			if ta_cmd.strip.empty?
				next
			end
			$_TA_BUFFER_.push ta_cmd
			$_CLIENT_.puts "(queued: #{ta_cmd.chomp})"
		else
			$TA_waiting_on_resp += 1
			$_SERVER_.puts client_string
		end
		$_CLIENTBUFFER_.push(client_string.dup)
		$_LASTUPSTREAM_ = client_string.dup
		Script.upscript_incoming(client_string)
	  rescue
		respond("--- Lich: error writing to #{$_SERVER_.inspect}: #{$!}")
	  end
	end
	unless aliasarray.empty?
		client_string = aliasarray.shift
		redo
	else
		running_alias = false
	end
end
break
rescue Exception
	respond "Lich bug: #{$!}"
	respond $!.backtrace.join("\r\n")
	$_LICHERRCNT_ += 1
rescue SystemExit
	respond "Lich bug: #{$!}"
	respond $!.backtrace.join("\r\n")
	$_LICHERRCNT_ += 1
rescue NoMemoryError
	respond "Lich bug: #{$!}"
	respond $!.backtrace.join("\r\n")
	$_LICHERRCNT_ += 1
rescue
	respond "Lich bug: #{$!}"
	respond $!.backtrace.join("\r\n")
	$_LICHERRCNT_ += 1
end
end
$_SERVER_.puts("quit") unless $_SERVER_.closed?
$_SERVER_.close unless $_SERVER_.closed?
$_CLIENT_.close unless $_CLIENT_.closed?
exit
}

# For using Lich with a non-Simu MUD; maximize efficiency
if $BARE_BONES
	server_thread = Thread.new {
		begin
			LichParser.bare_loop
		rescue
			respond("--- Lich encountered an error: #{$!}")
			respond($!.backtrace.join("\r\n"))
			$_LICHERRCNT_ += 1
			respond("--- Lich: this error is non-fatal, continuing as usual.")
		end
	}
elsif !$stormfront
 server_thread = Thread.new {
until $_CLIENT_.closed? or $_SERVER_.closed?
begin
	LichParser.gsl_loop
  break
rescue
	$_CLIENT_.puts("Lich #{$version} StandardError: #{$!}")
	$_CLIENT_.puts($!.backtrace.join("\r\n"))
	$_LICHERRCNT_ += 1
rescue Exception
	if $!.to_s =~ /invalid argument/io
		$_CLIENT_.puts("Lich #{$version}: the file descriptor for Lich's game socket is no longer recognized by Windows as a valid connection; either the game has crashed or you were dropped for inactivity and Lich wasn't notified that the socket has been closed.  There isn't much I can do to get around this random quirk in Windows.") if $LICH_DEBUG
		$_CLIENT_.puts($!.to_s) if $LICH_DEBUG
		$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
		$_LICHERRCNT_ = 5
	else	
		$_CLIENT_.puts("Lich #{$version} Exception: #{$!}") if $LICH_DEBUG
		$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
		$_LICHERRCNT_ += 1
	end
rescue SystemExit
	$_CLIENT_.puts("Lich #{$version} SystemExit: #{$!}") if $LICH_DEBUG
	$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
	$_LICHERRCNT_ += 1
end
end
  respond("--- Lich's link to the game was closed, closing clients...") if $LICH_DEBUG
  respond("\r\n\r\n") if $LICH_DEBUG
  $_CLIENT_.close unless $_CLIENT_.closed?
  $_SERVER_.puts("quit") unless $_SERVER_.closed?
  $_SERVER_.close unless $_SERVER_.closed?
  exit
 }
else
 server_thread = Thread.new {
	$_TAGHASH_['GSa'] = '0000000000'
	$_TAGHASH_['GSb'] = '0000000000'
	$_TAGHASH_['GSP'] = String.new
	stat = String.new; xpdata = String.new
	thoughtflag = false
until $_SERVER_.closed? or $_CLIENT_.closed?
begin
  while $_SERVERSTRING_ = $_SERVER_.gets
	$_CLIENT_.write($_SERVERSTRING_)
	$_SERVERBUFFER_.push($_SERVERSTRING_)
	$_SFPARSER_.parse($_SERVERSTRING_)
	$_SFPARSER_.endline
	_simustring_ = $_SERVERSTRING_.gsub(/#{_SFPARSEREGEXP_}/o, '')
	Script.statscript_incoming($_SERVERSTRING_)
	unless _simustring_ =~ /^\s\*\s[A-Z][a-z]+ (?:returns home from a hard day of adventuring|joins the adventure|just bit the dust)|^\r*\n*$/o
		Script.namescript_incoming(_simustring_) unless _simustring_.empty? or $_SFPARSER_.current_stream
	end
  end
  break
rescue Exception
	if $!.to_s =~ /invalid argument/oi
		$_CLIENT_.puts "Lich #{$version}: the file descriptor for Lich's game socket is no longer recognized by Windows as a valid connection; either the game has crashed or you were dropped for inactivity and Lich wasn't notified that the socket has been closed.  There isn't much I can do to get around this random quirk in Windows." if $LICH_DEBUG
		$_CLIENT_.puts($!.to_s) if $LICH_DEBUG
		$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
		$_LICHERRCNT_ = 5
	else
		$_CLIENT_.puts("Lich #{$version} Exception: #{$!}") if $LICH_DEBUG
		$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
		$_LICHERRCNT_ += 1
	end
rescue SystemExit
	$_CLIENT_.puts("Lich #{$version} SystemError: #{$!}") if $LICH_DEBUG
	$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
	$_LICHERRCNT_ += 1
rescue
	$_CLIENT_.puts("Lich #{$version} StandardError: #{$!}") if $LICH_DEBUG
	$_CLIENT_.puts($!.backtrace.join("\r\n")) if $LICH_DEBUG
	$_LICHERRCNT_ += 1
end
end
  respond("--- Lich's connection to the game has been closed.") if $LICH_DEBUG and !$_CLIENT_.closed?
  respond("\r\n\r\n") if $LICH_DEBUG and !$_CLIENT_.closed?
  $_CLIENT_.close unless $_CLIENT_.closed?
  $_SERVER_.puts("<c>quit") unless $_SERVER_.closed?
  $_SERVER_.close unless $_SERVER_.closed?
  exit
 }
end

server_thread.priority = 4
client_thread.priority = 3

if ARGV.find { |arg| arg =~ /^--debug$/ }
	$stderr.close unless $stderr.closed?
end
$stdout = $_CLIENT_
unless ARGV.find { |arg| arg =~ /^--stderr$/ }
	$stderr = $_CLIENT_
else
	$stderr.puts "$stderr will not be redirected."
end

$_CLIENT_.sync = true
$_SERVER_.sync = true

$_CLIENT_.write("--- Lich v#{$version} caught the connection and is active. Type #{$clean_lich_char}help for usage info.\r\n\r\n")
fav_timeout = 0
until $_SERVERBUFFER_.find { |line| line =~ /Welcome to GemStone/i } or $_SERVERBUFFER_.to_a.length > 5
	sleep 1
end
if $_SERVERBUFFER_.find { |line| line =~ /Welcome to GemStone.+Platinum/i }
	$_GSPLAT_ = true
end
sleep 1
if ($stormfront || $_FAKE_STORMFRONT)
	nametimeout = 0
	character_name = $_SERVERBUFFER_.find { |line| line =~ /<app char="\w+"/ }
	while character_name.nil?
		character_name = $_SERVERBUFFER_.find { |line| line =~ /<app char="\w+"/ }
		nametimeout += 1
		break if nametimeout >= 15
		sleep 0.5
	end
	unless character_name.nil?
		Char.init(character_name.dup.chomp.slice(/<app char\=\"\w+\"/).gsub(/<app char\=\"|\"/,''))
		Lich.reload_settings
	end
else
	nametimeout = 0
	character_name = $_TAGHASH_['GSB'].slice(/[A-Z][a-z]+/) || $_SERVERBUFFER_.find { |line| line =~ /\034GSB/ }.slice(/[A-Z][a-z]+/)
	cha = $_SERVERBUFFER_.find { |line| line =~ /^\034GSA/ }
	unless cha.nil? then Char.cha(cha) end
	unless character_name.nil? then Char.init(character_name.dup.chomp.sub(/\034GSB[0-9]+/, '')); Lich.reload_settings end
end

# Overwrite the user's encrypted login key before loading the favorites list (make sure it's gone before a script could possibly start and snag it)
$_CLIENTBUFFER_[0] = "*** (encrypted login key would be here, but it is erased by Lich immediately after use) ***"
# Call the garbage collector to make as certain as possible the key is gone forever (it's overkill, but it can't hurt...)
GC.start

def show_notice
	unless $stormfront
		respond("\034GSL")
	else
#		respond('<output class="mono"/>')
#		respond('<pushBold/>')
	end
	respond
	respond("** NOTICE:")
	respond("** Lich is not intended to facilitate AFK scripting.")
	respond("** The author does not condone violation of game policy,")
	respond("** nor is he in any way attempting to encourage it.")
	respond
	if $stormfront
		respond("** (this notice will never repeat, it's one-time-only)")
	else
		respond("** (this notice will never repeat, it's one-time-only)\034GSM")
#		respond('<popBold/>')
#		respond('<output class=""/>')
	end
	respond("\r\n")
end

unless File.exists?("#{lich_dir}notfirst.txt") or !$_SERVERBUFFER_.find { |line| line =~ /GemStone|DragonRealm/i }
	begin
		show_notice
		file = File.open("#{lich_dir}notfirst.txt", "w"); file.puts("just tracks if this is your first run or not"); file.close; file = nil
		if File.exists?(lich_dir + 'favorites.txt')
			file = File.open(lich_dir + 'favorites.txt'); data = file.readlines; file.close; file = nil
			data.unshift("ALL:infomonitor\nALL:lichnet\n") unless data.find { |line| line =~ /^ALL:infomonitor/ || line =~ /^ALL:lichnet/ }
			file = File.open(lich_dir + 'favorites.txt','w'); file.puts(data); file.close; file = nil
		else
			file = File.open(lich_dir + 'favorites.txt','w'); file.puts("ALL:infomonitor\nALL:lichnet"); file.close; file = nil
		end
		respond
		respond("For your convenience, the 'InfoMonitor' and 'LichNet' scripts have been added as global favorites. 'infomonitor.lic' is responsible for tracking your character statistics, active spells, and just about everything else that isn't automatically updated by the game server for the front-end's use (meaning basically anything your front-end does not have a graphical display for).  'lichnet.lic' is the client for the LichNet chat server, which is a blatant clone of PsiNet's OOC chat channel; I wrote the server just to learn how to do it, and since I have it, might as well run it.  If you'd like to remove either of these from your favorites list, you can do so at anytime by typing:  '#{$clean_lich_char}favs del all lichnet'  or  '#{$clean_lich_char}favs del all infomonitor'  (type '#{$clean_lich_char}help' for further information).")
	rescue
		respond("There's been an unknown error recording that you've seen this notice. I'm sorry, but it appears Lich will")
		respond("have to repeat this notice every login: #{$!.chomp}.")
	end
end

if fav_timeout <= 15 or $BARE_BONES or $_SERVERBUFFER_.length > 5
	if $_SERVERBUFFER_.find { |line| line =~ /GemStone|DragonRealm|Modus/i }
		$SIMUGAME = true
	end
	begin
		sleep 0.5
		list = load_favs(lich_dir,script_dir,true).join(', ')
		sleep 0.25
		respond("\r\n--- Lich: started #{list}.\r\n")
	rescue
		respond; respond("Fatal error trying to start the scripts on your favorites list: #{$!}"); respond
	end
else
	respond("--- Lich: favorites list will not be auto loaded; timed out while trying to verify an active link to the game.")
end
fav_timeout = nil

undef :hack_hosts
undef :open_client
undef :open_gs
if defined?(launch_sge_win)
	undef :launch_sge_win
end
if defined?(launch_sge_nix)
	undef :launch_sge_nix
end
undef :launch_sge_user

begin
	server_thread.join
rescue Exception
	$_LICHERRCNT_ += 1
	if server_thread.alive? and !$_CLIENT_.closed? and !$_SERVER_.closed?
		respond "Exception bug: #{$!}" if $LICH_DEBUG
		respond $!.backtrace.join("\r\n") if $LICH_DEBUG
		retry
	end
	respond "Fatal (non-recoverable) error during execution: #{$!}" if $LICH_DEBUG
	respond $!.backtrace.join("\r\n") if $LICH_DEBUG
rescue SystemExit
	$_LICHERRCNT_ += 1
	if server_thread.alive? and !$_CLIENT_.closed? and !$_SERVER_.closed?
		respond "SystemExit bug: #{$!}" if $LICH_DEBUG
		respond $!.backtrace.join("\r\n") if $LICH_DEBUG
		retry
	end
	respond "Fatal (non-recoverable) error during execution: #{$!}" if $LICH_DEBUG
	respond $!.backtrace.join("\r\n") if $LICH_DEBUG
rescue
	$_LICHERRCNT_ += 1
	if server_thread.alive? and !$_CLIENT_.closed? and !$_SERVER_.closed?
		respond "StandardError bug: #{$!}" if $LICH_DEBUG
		respond $!.backtrace.join("\r\n") if $LICH_DEBUG
		retry
	end
	respond "Fatal (non-recoverable) error during execution: #{$!}" if $LICH_DEBUG
	respond $!.backtrace.join("\r\n") if $LICH_DEBUG
end
#$_SERVER_.puts("quit") if ($_SERVER_.respond_to?(:puts) and !($_SERVER_.closed?))
exit
