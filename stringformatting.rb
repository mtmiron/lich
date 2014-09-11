module StringFormatting
  def as_time
    sprintf("%d:%02d:%02d", (self / 60).truncate, self.truncate % 60, ((self % 1) * 60).truncate)
  end
end

class Numeric
	include StringFormatting
end

=begin
class Fixnum
	include StringFormatting
end

class Bignum
	include StringFormatting
end

class Float
	include StringFormatting
end
=end
