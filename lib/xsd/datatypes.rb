# XSD4R - XML Schema Datatype implementation.
# Copyright (C) 2000, 2001, 2002, 2003  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'xsd/qname'
require 'xsd/charset'
require 'uri'


###
## XMLSchamaDatatypes general definitions.
#
module XSD


Namespace = 'http://www.w3.org/2001/XMLSchema'
InstanceNamespace = 'http://www.w3.org/2001/XMLSchema-instance'

AttrType = 'type'
NilValue = 'true'

AnyTypeLiteral = 'anyType'
AnySimpleTypeLiteral = 'anySimpleType'
NilLiteral = 'nil'
StringLiteral = 'string'
BooleanLiteral = 'boolean'
DecimalLiteral = 'decimal'
FloatLiteral = 'float'
DoubleLiteral = 'double'
DurationLiteral = 'duration'
DateTimeLiteral = 'dateTime'
TimeLiteral = 'time'
DateLiteral = 'date'
GYearMonthLiteral = 'gYearMonth'
GYearLiteral = 'gYear'
GMonthDayLiteral = 'gMonthDay'
GDayLiteral = 'gDay'
GMonthLiteral = 'gMonth'
HexBinaryLiteral = 'hexBinary'
Base64BinaryLiteral = 'base64Binary'
AnyURILiteral = 'anyURI'
QNameLiteral = 'QName'

NormalizedStringLiteral = 'normalizedString'
IntegerLiteral = 'integer'
LongLiteral = 'long'
IntLiteral = 'int'
ShortLiteral = 'short'

AttrTypeName = QName.new(InstanceNamespace, AttrType)
AttrNilName = QName.new(InstanceNamespace, NilLiteral)

AnyTypeName = QName.new(Namespace, AnyTypeLiteral)
AnySimpleTypeName = QName.new(Namespace, AnySimpleTypeLiteral)

class Error < StandardError; end
class ValueSpaceError < Error; end


###
## The base class of all datatypes with Namespace.
#
class NSDBase
  @@types = []

  attr_accessor :type

  def self.inherited(klass)
    @@types << klass
  end

  def self.types
    @@types
  end

  def initialize
    @type = nil
  end
end


###
## The base class of XSD datatypes.
#
class XSDAnySimpleType < NSDBase
  include XSD
  Type = QName.new(Namespace, AnySimpleTypeLiteral)

  # @data represents canonical space (ex. Integer: 123).
  attr_reader :data
  # @is_nil represents this data is nil or not.
  attr_accessor :is_nil

  def initialize(value = nil)
    super()
    @type = Type
    @data = nil
    @is_nil = true
    set(value) if value
  end

  # set accepts a string which follows lexical space (ex. String: "+123"), or
  # an object which follows canonical space (ex. Integer: 123).
  def set(value)
    if value.nil?
      @is_nil = true
      @data = nil
    else
      @is_nil = false
      _set(value)
    end
  end

  # to_s creates a string which follows lexical space (ex. String: "123").
  def to_s()
    if @is_nil
      ""
    else
      _to_s
    end
  end

private

  def _set(value)
    @data = value
  end

  def _to_s
    @data.to_s
  end
end

class XSDNil < XSDAnySimpleType
  Type = QName.new(Namespace, NilLiteral)
  Value = 'true'

  def initialize(value = nil)
    super()
    @type = Type
    set(value)
  end

private

  def _set(value)
    @data = value
  end
end


###
## Primitive datatypes.
#
class XSDString < XSDAnySimpleType
  Type = QName.new(Namespace, StringLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    unless XSD::Charset.is_ces(value, XSD::Charset.encoding)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    @data = value
  end
end

class XSDBoolean < XSDAnySimpleType
  Type = QName.new(Namespace, BooleanLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value)
  end

private

  def _set(value)
    if value.is_a?(String)
      str = value.strip
      if str == 'true' || str == '1'
	@data = true
      elsif str == 'false' || str == '0'
	@data = false
      else
	raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
      end
    else
      @data = value ? true : false
    end
  end
end

class XSDDecimal < XSDAnySimpleType
  Type = QName.new(Namespace, DecimalLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    @sign = ''
    @number = ''
    @point = 0
    set(value) if value
  end

  def nonzero?
    (@number != '0')
  end

private

  def _set(d)
    if d.is_a?(String)
      # Integer("00012") => 10 in Ruby.
      d.sub!(/^([+\-]?)0*(?=\d)/, "\\1")
    end
    set_str(d)
  end

  def set_str(str)
    /^([+\-]?)(\d*)(?:\.(\d*)?)?$/ =~ str.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end

    @sign = $1 || '+'
    int_part = $2
    frac_part = $3

    int_part = '0' if int_part.empty?
    frac_part = frac_part ? frac_part.sub(/0+$/, '') : ''
    @point = - frac_part.size
    @number = int_part + frac_part

    # normalize
    if @sign == '+'
      @sign = ''
    elsif @sign == '-'
      if @number == '0'
	@sign = ''
      end
    end

    @data = _to_s
    @data.freeze
  end

  # 0.0 -> 0; right?
  def _to_s
    str = @number.dup
    if @point.nonzero?
      str[@number.size + @point, 0] = '.'
    end
    @sign + str
  end
end

module FloatConstants
  NaN = 0.0/0.0
  POSITIVE_INF = 1.0/0.0
  NEGATIVE_INF = -1.0/0.0
end

class XSDFloat < XSDAnySimpleType
  include FloatConstants
  Type = QName.new(Namespace, FloatLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    # "NaN".to_f => 0 in some environment.  libc?
    if value.is_a?(Float)
      @data = narrow32bit(value)
      return
    end

    str = value.to_s.strip
    if str == 'NaN'
      @data = NaN
    elsif str == 'INF'
      @data = POSITIVE_INF
    elsif str == '-INF'
      @data = NEGATIVE_INF
    else
      if /^[+\-\.\deE]+$/ !~ str
	raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
      end
      # Float("-1.4E") might fail on some system.
      str << '0' if /e$/i =~ str
      begin
  	@data = narrow32bit(Float(str))
      rescue ArgumentError
  	raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
      end
    end
  end

  def _to_s
    if @data.nan?
      'NaN'
    elsif @data.infinite? == 1
      'INF'
    elsif @data.infinite? == -1
      '-INF'
    else
      sign = (1 / @data > 0.0) ? '+' : '-'
      sign + sprintf("%.10g", @data.abs).sub(/[eE]([+-])?0+/) { 'e' + $1 }
    end
  end

  # Convert to single-precision 32-bit floating point value.
  def narrow32bit(f)
    if f.nan? || f.infinite?
      f
    else
      packed = [f].pack("f")
      (/\A\0*\z/ =~ packed)? 0.0 : f
    end
  end
end

# Ruby's Float is double-precision 64-bit floating point value.
class XSDDouble < XSDAnySimpleType
  include FloatConstants
  Type = QName.new(Namespace, DoubleLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    # "NaN".to_f => 0 in some environment.  libc?
    if value.is_a?(Float)
      @data = value
      return
    end

    str = value.to_s.strip
    if str == 'NaN'
      @data = NaN
    elsif str == 'INF'
      @data = POSITIVE_INF
    elsif str == '-INF'
      @data = NEGATIVE_INF
    else
      begin
	@data = Float(str)
      rescue ArgumentError
	# '1.4e' cannot be parsed on some architecture.
	if /e\z/i =~ str
	  begin
	    @data = Float(str + '0')
	  rescue ArgumentError
	    raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
	  end
	else
	  raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
	end
      end
    end
  end

  def _to_s
    if @data.nan?
      'NaN'
    elsif @data.infinite? == 1
      'INF'
    elsif @data.infinite? == -1
      '-INF'
    else
      sign = (1 / @data > 0.0) ? '+' : '-'
      sign + sprintf("%.16g", @data.abs).sub(/[eE]([+-])?0+/) { 'e' + $1 }
    end
  end
end

class XSDDuration < XSDAnySimpleType
  Type = QName.new(Namespace, DurationLiteral)

  attr_accessor :sign
  attr_accessor :year
  attr_accessor :month
  attr_accessor :day
  attr_accessor :hour
  attr_accessor :min
  attr_accessor :sec

  def initialize(value = nil)
    super()
    @type = Type
    @sign = nil
    @year = nil
    @month = nil
    @day = nil
    @hour = nil
    @min = nil
    @sec = nil
    set(value) if value
  end

private

  def _set(value)
    /^([+\-]?)P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/ =~ value.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end

    if ($5 and ((!$2 and !$3 and !$4) or (!$6 and !$7 and !$8)))
      # Should we allow 'PT5S' here?
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end

    @sign = $1
    @year = $2.to_i
    @month = $3.to_i
    @day = $4.to_i
    @hour = $6.to_i
    @min = $7.to_i
    @sec = $8 ? XSDDecimal.new($8) : 0
    @data = _to_s
    @data.freeze
  end

  def _to_s
    str = ''
    str << @sign if @sign
    str << 'P'
    l = ''
    l << "#{ @year }Y" if @year.nonzero?
    l << "#{ @month }M" if @month.nonzero?
    l << "#{ @day }D" if @day.nonzero?
    r = ''
    r << "#{ @hour }H" if @hour.nonzero?
    r << "#{ @min }M" if @min.nonzero?
    r << "#{ @sec }S" if @sec.nonzero?
    str << l
    if l.empty?
      str << "0D"
    end
    unless r.empty?
      str << "T" << r
    end
    str
  end
end


require 'rational'
require 'date'

module XSDDateTimeImpl
  SecInDay = 86400	# 24 * 60 * 60

  def to_time
    begin
      if @data.offset * SecInDay == Time.now.utc_offset
        d = @data
	usec = (d.sec_fraction * SecInDay * 1000000).round
        Time.local(d.year, d.month, d.mday, d.hour, d.min, d.sec, usec)
      else
        d = @data.newof
	usec = (d.sec_fraction * SecInDay * 1000000).round
        Time.gm(d.year, d.month, d.mday, d.hour, d.min, d.sec, usec)
      end
    rescue ArgumentError
      nil
    end
  end

  def tz2of(str)
    /^(?:Z|(?:([+\-])(\d\d):(\d\d))?)$/ =~ str
    sign = $1
    hour = $2.to_i
    min = $3.to_i

    of = case sign
      when '+'
	of = +(hour.to_r * 60 + min) / 1440	# 24 * 60
      when '-'
	of = -(hour.to_r * 60 + min) / 1440	# 24 * 60
      else
	0
      end
    of
  end

  def of2tz(offset)
    diffmin = offset * 24 * 60
    if diffmin.zero?
      'Z'
    else
      ((diffmin < 0) ? '-' : '+') << format('%02d:%02d',
    	(diffmin.abs / 60.0).to_i, (diffmin.abs % 60.0).to_i)
    end
  end

  def _set(t)
    set_datetime_init(t)
    if (t.is_a?(Date))
      @data = t
    elsif (t.is_a?(Time))
      sec, min, hour, mday, month, year = t.to_a[0..5]
      diffday = t.usec.to_r / 1000000 / SecInDay
      of = t.utc_offset.to_r / SecInDay
      @data = DateTime.civil(year, month, mday, hour, min, sec, of)
      @data += diffday
    else
      set_str(t)
    end
  end

  def add_tz(s)
    s + of2tz(@data.offset)
  end
end

class XSDDateTime < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, DateTimeLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    @secfrac = nil
    set(value) if value
  end

private

  def set_datetime_init(t)
    @secfrac = nil
  end

  def set_str(t)
    /^([+\-]?\d{4,})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d(?:\.(\d*))?)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end
    if $1 == '0000'
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    mon = $2.to_i
    mday = $3.to_i
    hour = $4.to_i
    min = $5.to_i
    sec = $6.to_i
    secfrac = $7
    zonestr = $8

    @data = DateTime.civil(year, mon, mday, hour, min, sec, tz2of(zonestr))
    @secfrac = secfrac

    if secfrac
      diffday = secfrac.to_i.to_r / (10 ** secfrac.size) / SecInDay
      # jd = @data.jd
      # day_fraction = @data.day_fraction + diffday
      # @data = DateTime.new0(DateTime.jd_to_rjd(jd, day_fraction,
      #   @data.offset), @data.offset)
      #
      # Thanks to Funaba-san, above code can be simply written as below.
      @data += diffday
      # FYI: new0 and jd_to_rjd are not necessary to use if you don't have
      # exceptional reason.
    end
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d-%02d-%02dT%02d:%02d:%02d',
      year, @data.mon, @data.mday, @data.hour, @data.min, @data.sec)
    if @data.sec_fraction.nonzero?
      if @secfrac
  	s << ".#{ @secfrac }"
      else
	s << sprintf("%.16f", (@data.sec_fraction * SecInDay).to_f).sub(/^0/, '').sub(/0*$/, '')
      end
    end
    add_tz(s)
  end
end

class XSDTime < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, TimeLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    @secfrac = nil
    set(value) if value
  end

private

  def set_datetime_init(t)
    @secfrac = nil
  end

  def set_str(t)
    /^(\d\d):(\d\d):(\d\d(?:\.(\d*))?)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    hour = $1.to_i
    min = $2.to_i
    sec = $3.to_i
    secfrac = $4
    zonestr = $5

    @data = DateTime.civil(1, 1, 1, hour, min, sec, tz2of(zonestr))
    @secfrac = secfrac

    if secfrac
      diffday = secfrac.to_i.to_r / (10 ** secfrac.size) / SecInDay
      @data += diffday
    end
  end

  def _to_s
    s = format('%02d:%02d:%02d', @data.hour, @data.min, @data.sec)
    if @data.sec_fraction.nonzero?
      if @secfrac
  	s << ".#{ @secfrac }"
      else
	s << sprintf("%.16f", (@data.sec_fraction * SecInDay).to_f).sub(/^0/, '').sub(/0*$/, '')
      end
    end
    add_tz(s)
  end
end

class XSDDate < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, DateLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_datetime_init(t)
  end

  def set_str(t)
    /^([+\-]?\d{4,})-(\d\d)-(\d\d)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    mon = $2.to_i
    mday = $3.to_i
    zonestr = $4

    @data = DateTime.civil(year, mon, mday, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d-%02d-%02d', year, @data.mon, @data.mday)
    add_tz(s)
  end
end

class XSDGYearMonth < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GYearMonthLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_datetime_init(t)
  end

  def set_str(t)
    /^([+\-]?\d{4,})-(\d\d)(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    mon = $2.to_i
    zonestr = $3

    @data = DateTime.civil(year, mon, 1, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d-%02d', year, @data.mon)
    add_tz(s)
  end
end

class XSDGYear < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GYearLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_datetime_init(t)
  end

  def set_str(t)
    /^([+\-]?\d{4,})(Z|(?:([+\-])(\d\d):(\d\d))?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    year = $1.to_i
    if year < 0
      year += 1
    end
    zonestr = $2

    @data = DateTime.civil(year, 1, 1, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    year = (@data.year > 0) ? @data.year : @data.year - 1
    s = format('%.4d', year)
    add_tz(s)
  end
end

class XSDGMonthDay < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GMonthDayLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_datetime_init(t)
  end

  def set_str(t)
    /^(\d\d)-(\d\d)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    mon = $1.to_i
    mday = $2.to_i
    zonestr = $3

    @data = DateTime.civil(1, mon, mday, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    s = format('%02d-%02d', @data.mon, @data.mday)
    add_tz(s)
  end
end

class XSDGDay < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GDayLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_datetime_init(t)
  end

  def set_str(t)
    /^(\d\d)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    mday = $1.to_i
    zonestr = $2

    @data = DateTime.civil(1, 1, mday, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    s = format('%02d', @data.mday)
    add_tz(s)
  end
end

class XSDGMonth < XSDAnySimpleType
  include XSDDateTimeImpl
  Type = QName.new(Namespace, GMonthLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_datetime_init(t)
  end

  def set_str(t)
    /^(\d\d)(Z|(?:[+\-]\d\d:\d\d)?)?$/ =~ t.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ t }'.")
    end

    mon = $1.to_i
    zonestr = $2

    @data = DateTime.civil(1, mon, 1, 0, 0, 0, tz2of(zonestr))
  end

  def _to_s
    s = format('%02d', @data.mon)
    add_tz(s)
  end
end

class XSDHexBinary < XSDAnySimpleType
  Type = QName.new(Namespace, HexBinaryLiteral)

  # String in Ruby could be a binary.
  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

  def set_encoded(value)
    if /^[0-9a-fA-F]*$/ !~ value
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    @data = String.new(value).strip
    @is_nil = false
  end

  def string
    [@data].pack("H*")
  end

private

  def _set(value)
    @data = value.unpack("H*")[0]
    @data.tr!('a-f', 'A-F')
  end
end

class XSDBase64Binary < XSDAnySimpleType
  Type = QName.new(Namespace, Base64BinaryLiteral)

  # String in Ruby could be a binary.
  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

  def set_encoded(value)
    if /^[A-Za-z0-9+\/=]*$/ !~ value
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    @data = String.new(value).strip
    @is_nil = false
  end

  def string
    @data.unpack("m")[0]
  end

private

  def _set(value)
    @data = [value].pack("m").strip
  end
end

class XSDAnyURI < XSDAnySimpleType
  Type = QName.new(Namespace, AnyURILiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    begin
      @data = URI.parse(value.to_s.strip)
    rescue URI::InvalidURIError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
  end
end

class XSDQName < XSDAnySimpleType
  Type = QName.new(Namespace, QNameLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    /^(?:([^:]+):)?([^:]+)$/ =~ value.to_s.strip
    unless Regexp.last_match
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end

    @prefix = $1
    @localpart = $2
    @data = _to_s
    @data.freeze
  end

  def _to_s
    if @prefix
      "#{ @prefix }:#{ @localpart }"
    else
      "#{ @localpart }"
    end
  end
end


###
## Derived types
#
class XSDNormalizedString < XSDString
  Type = QName.new(Namespace, NormalizedStringLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def _set(value)
    if /[\t\r\n]/ =~ value
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ value }'.")
    end
    super
  end
end

class XSDInteger < XSDDecimal
  Type = QName.new(Namespace, IntegerLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  def _to_s()
    @data.to_s
  end
end

class XSDLong < XSDInteger
  Type = QName.new(Namespace, LongLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
    unless validate(@data)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  MaxInclusive = +9223372036854775807
  MinInclusive = -9223372036854775808
  def validate(v)
    ((MinInclusive <= v) && (v <= MaxInclusive))
  end
end

class XSDInt < XSDLong
  Type = QName.new(Namespace, IntLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
    unless validate(@data)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  MaxInclusive = +2147483647
  MinInclusive = -2147483648
  def validate(v)
    ((MinInclusive <= v) && (v <= MaxInclusive))
  end
end

class XSDShort < XSDInt
  Type = QName.new(Namespace, ShortLiteral)

  def initialize(value = nil)
    super()
    @type = Type
    set(value) if value
  end

private

  def set_str(str)
    begin
      @data = Integer(str)
    rescue ArgumentError
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
    unless validate(@data)
      raise ValueSpaceError.new("#{ type }: cannot accept '#{ str }'.")
    end
  end

  MaxInclusive = +32767
  MinInclusive = -32768
  def validate(v)
    ((MinInclusive <= v) && (v <= MaxInclusive))
  end
end


end
