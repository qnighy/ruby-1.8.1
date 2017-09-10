# SOAP4R - SOAP elements library
# Copyright (C) 2000, 2001, 2003  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'xsd/qname'
require 'soap/baseData'


module SOAP


###
## SOAP elements
#
module SOAPEnvelopeElement; end

class SOAPFault < SOAPStruct
  include SOAPEnvelopeElement
  include SOAPCompoundtype

public

  def faultcode
    self['faultcode']
  end

  def faultstring
    self['faultstring']
  end

  def faultactor
    self['faultactor']
  end

  def detail
    self['detail']
  end

  def faultcode=(rhs)
    self['faultcode'] = rhs
  end

  def faultstring=(rhs)
    self['faultstring'] = rhs
  end

  def faultactor=(rhs)
    self['faultactor'] = rhs
  end

  def detail=(rhs)
    self['detail'] = rhs
  end

  def initialize(faultcode = nil, faultstring = nil, faultactor = nil, detail = nil)
    super(EleFaultName)
    @elename = EleFaultName
    @encodingstyle = EncodingNamespace

    if faultcode
      self.faultcode = faultcode
      self.faultstring = faultstring
      self.faultactor = faultactor
      self.detail = detail
      self.faultcode.elename = EleFaultCodeName if self.faultcode
      self.faultstring.elename = EleFaultStringName if self.faultstring
      self.faultactor.elename = EleFaultActorName if self.faultactor
      self.detail.elename = EleFaultDetailName if self.detail
    end
  end

  def encode(generator, ns, attrs = {})
    SOAPGenerator.assign_ns(attrs, ns, EnvelopeNamespace)
    SOAPGenerator.assign_ns(attrs, ns, EncodingNamespace)
    attrs[ns.name(AttrEncodingStyleName)] = EncodingNamespace
    name = ns.name(@elename)
    generator.encode_tag(name, attrs)
    yield(self.faultcode, false)
    yield(self.faultstring, false)
    yield(self.faultactor, false)
    yield(self.detail, false) if self.detail
    generator.encode_tag_end(name, true)
  end
end


class SOAPBody < SOAPStruct
  include SOAPEnvelopeElement

public

  def initialize(data = nil, is_fault = false)
    super(nil)
    @elename = EleBodyName
    @encodingstyle = nil
    add(data.elename.name, data) if data
    @is_fault = is_fault
  end

  def encode(generator, ns, attrs = {})
    name = ns.name(@elename)
    generator.encode_tag(name, attrs)
    if @is_fault
      yield(@data, true)
    else
      @data.each do |data|
	yield(data, true)
      end
    end
    generator.encode_tag_end(name, true)
  end

  def root_node
    @data.each do |node|
      if node.root == 1
	return node
      end
    end
    # No specified root...
    @data.each do |node|
      if node.root != 0
	return node
      end
    end

    raise SOAPParser::FormatDecodeError.new('No root element.')
  end
end


class SOAPHeaderItem < XSD::NSDBase
  include SOAPEnvelopeElement
  include SOAPCompoundtype

public

  attr_accessor :content
  attr_accessor :mustunderstand
  attr_accessor :encodingstyle

  def initialize(content, mustunderstand = true, encodingstyle = nil)
    super(nil)
    @content = content
    @mustunderstand = mustunderstand
    @encodingstyle = encodingstyle || LiteralNamespace
  end

  def encode(generator, ns, attrs = {})
    attrs.each do |key, value|
      @content.attr[key] = value
    end
    @content.attr[ns.name(EnvelopeNamespace, AttrMustUnderstand)] =
      (@mustunderstand ? '1' : '0')
    if @encodingstyle
      @content.attr[ns.name(EnvelopeNamespace, AttrEncodingStyle)] =
      	@encodingstyle
    end
    @content.encodingstyle = @encodingstyle if !@content.encodingstyle
    yield(@content, true)
  end
end


class SOAPHeader < SOAPArray
  include SOAPEnvelopeElement

  def initialize()
    super(nil, 1)	# rank == 1
    @elename = EleHeaderName
    @encodingstyle = nil
  end

  def encode(generator, ns, attrs = {})
    name = ns.name(@elename)
    generator.encode_tag(name, attrs)
    @data.each do |data|
      yield(data, true)
    end
    generator.encode_tag_end(name, true)
  end

  def length
    @data.length
  end
end


class SOAPEnvelope < XSD::NSDBase
  include SOAPEnvelopeElement
  include SOAPCompoundtype

  attr_accessor :header
  attr_accessor :body

  def initialize(header = nil, body = nil)
    super(nil)
    @elename = EleEnvelopeName
    @encodingstyle = nil
    @header = header
    @body = body
  end

  def encode(generator, ns, attrs = {})
    SOAPGenerator.assign_ns(attrs, ns, EnvelopeNamespace,
      SOAPNamespaceTag)
    name = ns.name(@elename)
    generator.encode_tag(name, attrs)

    yield(@header, true) if @header and @header.length > 0
    yield(@body, true)

    generator.encode_tag_end(name, true)
  end
end


end
