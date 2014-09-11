class Settings
	@@hash ||= {}
	@@auto ||= false
	@@stamp ||= Hash.new
	def Settings.auto=(val)
		@@auto = val
	end
	def Settings.auto
		@@auto
	end
	def Settings.save
		if script = Script.self
			if File.exists?($script_dir + script.to_s + ".sav")
				File.rename($script_dir + script.to_s + ".sav",
				            $data_dir + script.to_s + ".sav")
			end
			file = File.open($data_dir + script.to_s + '.sav', 'wb')
			file.write(Marshal.dump(if @@hash[script.to_s] then @@hash[script.to_s] else {} end))
			file.close
		else
			raise Exception.exception("SettingsError"), "The script trying to save its data cannot be identified!"
		end
	end
	def Settings.autoload
		if File.exists?($script_dir + Script.self.to_s + ".sav")
			File.rename($script_dir + Script.self.to_s + ".sav",
			            $data_dir + Script.self.to_s + ".sav")
		end
		fname = $data_dir + Script.self.to_s + '.sav'
		if File.mtime(fname) > @@stamp[Script.self.to_s]
			Settings.load
			true
		else
			false
		end
	end
	def Settings.load(who = nil)
		@@stamp[Script.self.to_s] = Time.now
		if !who.nil?
			unless who.include?(".")
				who += ".sav"
			end
			begin
				if File.exists?($script_dir + who)
					File.rename($script_dir + who, $data_dir + who)
				end
				file = File.open($data_dir + who, 'rb')
				@@hash[who.sub(/\..*/, '')] = Marshal.load(file.read)
			rescue
				$stderr.puts $!
				$stderr.puts $!.backtrace
			ensure
				file.close unless file.closed?
			end
			return
		end
		if script = Script.self
			if File.exists?($script_dir + script.to_s + '.sav')
				File.rename($script_dir + script.to_s + ".sav",
				            $data_dir + script.to_s + ".sav")
			end
			if File.exists?($data_dir + script.to_s + ".sav")
				begin
					file = File.open($data_dir + script.to_s + '.sav', 'rb')
					data = Marshal.load(file.read)
					file.close
					@@hash[script.to_s] = data
				rescue
					puts $!
				ensure
					file.close unless file.closed?
				end
			else
				nil
			end
		else
			raise Exception.exception("SettingsError"), "The script trying to load data cannot be identified!"
		end
	end
	def Settings.clear
		unless script = Script.self then raise Exception.exception("SettingsError"), "The script trying to access settings cannot be identified!" end
		unless @@hash[script.to_s] then @@hash[script.to_s] = {} end
		@@hash[script.to_s].clear
	end
	def Settings.[](val)
		Settings.autoload if @@auto
		unless script = Script.self then raise Exception.exception("SettingsError"), "The script trying to access settings cannot be identified!" end
		unless @@hash[script.to_s] then @@hash[script.to_s] = {} end
		@@hash[script.to_s][val]
	end
	def Settings.[]=(setting, val)
		unless script = Script.self then raise Exception.exception("SettingsError"), "The script trying to access settings cannot be identified!" end
		unless @@hash[script.to_s] then @@hash[script.to_s] = {} end
		@@hash[script.to_s][setting] = val
		Settings.save if @@auto
		@@hash[script.to_s][setting]
	end
	def Settings.to_hash
		unless script = Script.self then raise Exception.exception("SettingsError"), "The script trying to access settings cannot be identified!" end
		unless @@hash[script.to_s] then @@hash[script.to_s] = {} end
		@@hash[script.to_s]
	end
end
