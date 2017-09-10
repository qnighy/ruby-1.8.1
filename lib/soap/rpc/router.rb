# SOAP4R - RPC Routing library
# Copyright (C) 2001, 2002  NAKAMURA, Hiroshi <nahi@ruby-lang.org>.

# This program is copyrighted free software by NAKAMURA, Hiroshi.  You can
# redistribute it and/or modify it under the same terms of Ruby's license;
# either the dual license version in 2003, or any later version.


require 'soap/soap'
require 'soap/processor'
require 'soap/mapping'
require 'soap/rpc/rpc'
require 'soap/rpc/element'


module SOAP
module RPC


class Router
  include SOAP

  attr_reader :actor
  attr_accessor :allow_unqualified_element
  attr_accessor :default_encodingstyle
  attr_accessor :mapping_registry

  def initialize(actor)
    @actor = actor
    @receiver = {}
    @method_name = {}
    @method = {}
    @allow_unqualified_element = false
    @default_encodingstyle = nil
    @mapping_registry = nil
  end

  def add_method(receiver, qname, soapaction, name, param_def)
    fqname = fqname(qname)
    @receiver[fqname] = receiver
    @method_name[fqname] = name
    @method[fqname] = RPC::SOAPMethodRequest.new(qname, param_def, soapaction)
  end

  def add_header_handler
    raise NotImplementedError.new
  end

  # Routing...
  def route(soap_string, charset = nil)
    opt = options
    opt[:charset] = charset
    is_fault = false
    begin
      header, body = Processor.unmarshal(soap_string, opt)
      # So far, header is omitted...
      soap_request = body.request
      unless soap_request.is_a?(SOAPStruct)
	raise RPCRoutingError.new("Not an RPC style.")
      end
      soap_response = dispatch(soap_request)
    rescue Exception
      soap_response = fault($!)
      is_fault = true
    end

    header = SOAPHeader.new
    body = SOAPBody.new(soap_response)
    response_string = Processor.marshal(header, body, opt)

    return response_string, is_fault
  end

  # Create fault response string.
  def create_fault_response(e, charset = nil)
    header = SOAPHeader.new
    soap_response = fault(e)
    body = SOAPBody.new(soap_response)
    opt = options
    opt[:charset] = charset
    Processor.marshal(header, body, opt)
  end

private

  # Create new response.
  def create_response(qname, result)
    name = fqname(qname)
    if (@method.key?(name))
      method = @method[name]
    else
      raise RPCRoutingError.new("Method: #{ name } not defined.")
    end

    soap_response = method.create_method_response
    if soap_response.have_outparam?
      unless result.is_a?(Array)
	raise RPCRoutingError.new("Out parameter was not returned.")
      end
      outparams = {}
      i = 1
      soap_response.each_param_name('out', 'inout') do |outparam|
	outparams[outparam] = Mapping.obj2soap(result[i], @mapping_registry)
	i += 1
      end
      soap_response.set_outparam(outparams)
      soap_response.retval = Mapping.obj2soap(result[0], @mapping_registry)
    else
      soap_response.retval = Mapping.obj2soap(result, @mapping_registry)
    end
    soap_response
  end

  # Create fault response.
  def fault(e)
    detail = Mapping::SOAPException.new(e)
    SOAPFault.new(
      SOAPString.new('Server'),
      SOAPString.new(e.to_s),
      SOAPString.new(@actor),
      Mapping.obj2soap(detail, @mapping_registry))
  end

  # Dispatch to defined method.
  def dispatch(soap_method)
    request_struct = Mapping.soap2obj(soap_method, @mapping_registry)
    values = soap_method.collect { |key, value| request_struct[key] }
    method = lookup(soap_method.elename, values)
    unless method
      raise RPCRoutingError.new(
	"Method: #{ soap_method.elename } not supported.")
    end

    result = method.call(*values)
    create_response(soap_method.elename, result)
  end

  # Method lookup
  def lookup(qname, values)
    name = fqname(qname)
    # It may be necessary to check all part of method signature...
    if @method.member?(name)
      @receiver[name].method(@method_name[name].intern)
    else
      nil
    end
  end

  def fqname(qname)
    "#{ qname.namespace }:#{ qname.name }"
  end

  def options
    opt = {}
    opt[:default_encodingstyle] = @default_encodingstyle
    if @allow_unqualified_element
      opt[:allow_unqualified_element] = true
    end
    opt
  end
end


end
end
