require 'test/unit'
require 'soap/rpc/driver'

dir = File.dirname(__FILE__)
$:.push(dir)
require 'hw_s.rb'
$:.delete(dir)


module SOAP
module HelloWorld


class TestHelloWorld < Test::Unit::TestCase
  Port = 17171

  def setup
    @server = HelloWorldServer.new('hws', 'urn:hws', '0.0.0.0', Port)
    @server.level = Logger::Severity::ERROR
    @t = Thread.new {
      Thread.current.abort_on_exception = true
      @server.start
    }
    while @server.status != :Running
      sleep 0.1
      unless @t.alive?
	@t.join
	raise
      end
    end
    @endpoint = "http://localhost:#{Port}/"
    @client = SOAP::RPC::Driver.new(@endpoint, 'urn:hws')
    @client.add_method("hello_world", "from")
  end

  def teardown
    @server.shutdown
    @t.kill
    @t.join
    @client.reset_stream
  end

  def test_hello_world
    assert_equal("Hello World, from NaHi", @client.hello_world("NaHi"))
    assert_equal("Hello World, from <&>", @client.hello_world("<&>"))
  end
end


end
end
