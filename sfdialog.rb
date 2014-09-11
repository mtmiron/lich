# Code related to displaying windows in StormFront

# Usage:

=begin

	window = SFDialog.new

	label1 = SFDialog::Label.new
	label1.id = "label1"
	label1.value = "I am a label"

	window.attach(label1)
	window.open
	window.update
	
=end

# ... et al, for SFDialog::Label, SFDialog::Link, and SFDialog::ProgressBar.
#
# Note that you'll almost certainly want to set the attribute fields, as the
# defaults are only safeguards against empty values being sent.


class SFDialog
	attr_accessor :type, :id, :title, :location, :height, :width, :resident
	attr_accessor :label, :link, :progressBar

	Label = Struct.new(:id, :value, :top, :left, :align, :width, :height, :anchor_top, :anchor_left, :anchor_right, :justify, :tooltip)
	Link = Struct.new(:id, :value, :cmd, :top, :left, :align, :echo, :width, :anchor_top, :anchor_left, :anchor_right, :justify, :tooltip)
	ProgressBar = Struct.new(:id, :value, :text, :top, :left, :align, :width, :height, :anchor_top, :anchor_left, :anchor_right, :justify, :tooltip)

	def initialize
		@label, @link, @progressBar = [],[],[]
		@id = @title = "lichDialog" + self.hash.abs.to_s
		@height, @width = '105', '450'
		@type = "dynamic"
		@location = 'right'
		@resident = 'true'
	end

	def contains
		@label + @link + @progressBar
	end

	def build_element(key)
		string = String.new
		instance_variable_get(key).each { |el|
			string += %[<#{key.to_s[1..-1]}]
			el.members.each { |attr|
				string += %[ #{attr.to_s}='#{el[attr].to_s}'] if el[attr]
			}
			string += "/>"
		}
		string
	end
	protected :build_element

	def elementData
		ary = [:@label, :@link, :@progressBar]
		ary.inject("") { |prev,cur| prev + build_element(cur) }
	end

	def open
		puts sprintf(%[<openDialog type='%s' id='%s' title='%s' location='%s' height='%s' width='%s' resident='%s'/>],
                   *([@type,@id,@title,@location,@height,@width,@resident].collect { |val| val.to_s }) ) if not @open_p
		@open_p = true
	end

	def closed
		@open_p = false
	end

	def update
		open
		string = sprintf(%[<dialogData id='%s'>], @id.to_s)
		string += elementData
		string += %[</dialogData>]
		puts string
	end

	def attach_label(lbl)
		@label.push(lbl)
		@label.uniq!
	end

	def attach_link(lnk)
		@link.push(lnk)
		@link.uniq!
	end

	def attach_progressbar(pbar)
		pbar.value = '50%' if pbar.respond_to? :value=
		@progressBar.push(pbar)
		@progressBar.uniq!
	end

	def init_attachment(obj)
		obj.id = obj.value = "lichObj" + obj.hash.abs.to_s unless obj.id or obj.value rescue()
		obj.top = '0' unless obj.top rescue() #if obj.respond_to? :top=
		obj.left = '0' unless obj.left rescue() #if obj.respond_to? :left=
		obj.width = '150' unless obj.width rescue() #if obj.respond_to? :width=
		obj.height = '15' unless obj.height rescue() #if obj.respond_to? :height=
		obj.align = 'n' unless obj.align rescue() #if obj.respond_to? :align=
		obj.cmd = "daydream #{Char.name} good" unless obj.cmd rescue() #if defined?(Char) and Char.respond_to? :name and obj.respond_to? :cmd=
		obj.echo = '(no command echo specified)' unless obj.echo rescue() #if obj.respond_to? :echo=
		obj.text = '(no text specified)' unless obj.text rescue() #if obj.respond_to? :text=
		obj.tooltip = 'Lich dialog item.' unless obj.tooltip rescue() #if obj.respond_to? :tooltip=
	end
	protected :init_attachment

	def attach(*objects)
		objects.flatten.each { |obj|
			init_attachment(obj)
			target = obj.class.to_s.slice(/\w+$/o)
			sym = sprintf("attach_%s", target.downcase)
			send(sym, obj)
		}
	end

end
