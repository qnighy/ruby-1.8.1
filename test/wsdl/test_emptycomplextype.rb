require 'test/unit'
require 'wsdl/parser'


module WSDL


class TestWSDL < Test::Unit::TestCase
  def setup
    @file = File.join(File.dirname(__FILE__), 'emptycomplextype.wsdl')
  end

  def test_wsdl
    @wsdl = WSDL::Parser.new.parse(File.open(@file) { |f| f.read })
    assert_equal("#<WSDL::Definitions:{urn:jp.gr.jin.rrr.example.emptycomplextype}emptycomplextype>", @wsdl.inspect)
  end
end



end
