require 'test/unit'
require 'uri'

module URI


class TestCommon < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_extract
    # ruby-list:36086
    assert_equal(['http://example.com'], 
		 URI.extract('http://example.com'))
    assert_equal(['http://example.com'], 
		 URI.extract('(http://example.com)'))
    assert_equal(['http://example.com/foo)'], 
		 URI.extract('(http://example.com/foo)'))
    assert_equal(['http://example.jphttp://example.jp'], 
		 URI.extract('http://example.jphttp://example.jp'))
    assert_equal(['http://example.jphttp://example.jp'], 
		 URI.extract('http://example.jphttp://example.jp', ['http']))
    assert_equal(['http://', 'mailto:'].sort, 
		 URI.extract('ftp:// http:// mailto: https://', ['http', 'mailto']).sort)
    # reported by Doug Kearns <djkea2@mugca.its.monash.edu.au>
    assert_equal(['From:', 'mailto:xxx@xxx.xxx.xxx]'].sort, 
		 URI.extract('From: XXX [mailto:xxx@xxx.xxx.xxx]').sort)
  end

  def test_regexp
    assert_instance_of Regexp, URI.regexp
    assert_instance_of Regexp, URI.regexp(['http'])
    assert_equal URI.regexp, URI.regexp
    assert_equal 'http://', 'x http:// x'.slice(URI.regexp)
    assert_equal 'http://', 'x http:// x'.slice(URI.regexp(['http']))
    assert_equal 'http://', 'x http:// x ftp://'.slice(URI.regexp(['http']))
    assert_equal nil, 'http://'.slice(URI.regexp([]))
    assert_equal nil, ''.slice(URI.regexp)
    assert_equal nil, 'xxxx'.slice(URI.regexp)
    assert_equal nil, ':'.slice(URI.regexp)
    assert_equal 'From:', 'From:'.slice(URI.regexp)
  end
end


end
