require 'test/unit'

$KCODE = 'none'

module MarshalTestLib
  def encode(o)
    Marshal.dump(o)
  end

  def decode(s)
    Marshal.load(s)
  end

  def marshaltest(o1)
    #o1.instance_eval { remove_instance_variable '@v' if defined? @v }
    str = encode(o1)
    print str, "\n" if $DEBUG
    o2 = decode(str)
    o2
  end

  def marshal_equal(o1)
    o2 = marshaltest(o1)
    assert_equal(o1.class, o2.class, caller[0])
    iv1 = o1.instance_variables.sort
    iv2 = o2.instance_variables.sort
    assert_equal(iv1, iv2)
    val1 = iv1.map {|var| o1.instance_eval {eval var}}
    val2 = iv1.map {|var| o2.instance_eval {eval var}}
    assert_equal(val1, val2, caller[0])
    if block_given?
      assert_equal(yield(o1), yield(o2), caller[0])
    else
      assert_equal(o1, o2, caller[0])
    end
  end

  class MyObject; def initialize(v) @v = v end; attr_reader :v; end
  def test_object
    o1 = Object.new
    o1.instance_eval { @iv = 1 }
    marshal_equal(o1) {|o| o.instance_eval { @iv }}
  end

  def test_object_subclass
    marshal_equal(MyObject.new(2)) {|o| o.v}
  end

  class MyArray < Array; def initialize(v, *args) super args; @v = v; end end
  def test_array
    marshal_equal([1,2,3])
  end

  def test_array_subclass
    marshal_equal(MyArray.new(0, 1,2,3))
  end

  class MyException < Exception; def initialize(v, *args) super(*args); @v = v; end; attr_reader :v; end
  def test_exception
    marshal_equal(Exception.new('foo')) {|o| o.message}
  end

  def test_exception_subclass
    marshal_equal(MyException.new(20, "bar")) {|o| [o.message, o.v]}
  end

  def test_false
    marshal_equal(false)
  end

  class MyHash < Hash; def initialize(v, *args) super(*args); @v = v; end end
  def test_hash
    marshal_equal({1=>2, 3=>4})
  end

  def test_hash_default
    h = Hash.new(:default)
    h[5] = 6
    marshal_equal(h)
  end

  def test_hash_subclass
    h = MyHash.new(7, 8)
    h[4] = 5
    marshal_equal(h)
  end

  def test_hash_default_proc
    h = Hash.new {}
    assert_raises(TypeError) { marshaltest(h) }
  end

  def test_bignum
    marshal_equal(-0x4000_0000_0000_0001)
    marshal_equal(-0x4000_0001)
    marshal_equal(0x4000_0000)
    marshal_equal(0x4000_0000_0000_0000)
  end

  def test_fixnum
    marshal_equal(-0x4000_0000)
    marshal_equal(-1)
    marshal_equal(0)
    marshal_equal(1)
    marshal_equal(0x3fff_ffff)
  end

  def test_float
    marshal_equal(-1.0)
    marshal_equal(0.0)
    marshal_equal(1.0)
  end

  def test_float_inf_nan
    marshal_equal(1.0/0.0)
    marshal_equal(-1.0/0.0)
    marshal_equal(0.0/0.0) {|o| o.nan?}
    marshal_equal(-0.0) {|o| 1.0/o}
  end

  class MyRange < Range; def initialize(v, *args) super(*args); @v = v; end end
  def test_range
    marshal_equal(1..2)
    marshal_equal(1...3)
  end

  def test_range_subclass
    marshal_equal(MyRange.new(4,5,8, false))
  end

  class MyRegexp < Regexp; def initialize(v, *args) super(*args); @v = v; end end
  def test_regexp
    marshal_equal(/a/)
  end

  def test_regexp_subclass
    marshal_equal(MyRegexp.new(10, "a"))
  end

  class MyString < String; def initialize(v, *args) super(*args); @v = v; end end
  def test_string
    marshal_equal("abc")
  end

  def test_string_subclass
    marshal_equal(MyString.new(10, "a"))
  end

  MyStruct = Struct.new("MyStruct", :a, :b)
  class MySubStruct < MyStruct; def initialize(v, *args) super(*args); @v = v; end end
  def test_struct
    marshal_equal(MyStruct.new(1,2))
  end

  def test_struct_subclass
    marshal_equal(MySubStruct.new(10,1,2))
  end

  def test_symbol
    marshal_equal(:a)
    marshal_equal(:a?)
    marshal_equal(:a!)
    marshal_equal(:a=)
    marshal_equal(:|)
    marshal_equal(:^)
    marshal_equal(:&)
    marshal_equal(:<=>)
    marshal_equal(:==)
    marshal_equal(:===)
    marshal_equal(:=~)
    marshal_equal(:>)
    marshal_equal(:>=)
    marshal_equal(:<)
    marshal_equal(:<=)
    marshal_equal(:<<)
    marshal_equal(:>>)
    marshal_equal(:+)
    marshal_equal(:-)
    marshal_equal(:*)
    marshal_equal(:/)
    marshal_equal(:%)
    marshal_equal(:**)
    marshal_equal(:~)
    marshal_equal(:+@)
    marshal_equal(:-@)
    marshal_equal(:[])
    marshal_equal(:[]=)
    marshal_equal(:`)   #`
    marshal_equal("a b".intern)
  end

  class MyTime < Time; def initialize(v, *args) super(*args); @v = v; end end
  def test_time
    marshal_equal(Time.now)
  end

  def test_time_subclass
    marshal_equal(MyTime.new(10))
  end

  def test_true
    marshal_equal(true)
  end

  def test_nil
    marshal_equal(nil)
  end

  def test_share
    o = [:share]
    o1 = [o, o]
    o2 = marshaltest(o1)
    assert_same(o2.first, o2.last)
  end

  class CyclicRange < Range
    def <=>(other); true; end
  end
  def test_range_cyclic
    o1 = CyclicRange.allocate
    o1.instance_eval { initialize(o1, o1) }
    o2 = marshaltest(o1)
    assert_same(o2, o2.begin)
    assert_same(o2, o2.end)
  end

  def test_singleton
    o = Object.new
    def o.m() end
    assert_raises(TypeError) { marshaltest(o) }
    o = Object.new
    class << o
      @v = 1
    end
    assert_raises(TypeError) { marshaltest(o) }
    assert_raises(TypeError) { marshaltest(ARGF) }
    assert_raises(TypeError) { marshaltest(ENV) }
  end

  module Mod1 end
  module Mod2 end
  def test_extend
    o = Object.new
    o.extend Mod1
    marshal_equal(o) { |obj| obj.kind_of? Mod1 }
    o = Object.new
    o.extend Module.new
    assert_raises(TypeError) { marshaltest(o) }
    o = Object.new
    o.extend Mod1
    o.extend Mod2
    marshal_equal(o) {|obj| class << obj; ancestors end}
  end

  def test_extend_string
    o = String.new
    o.extend Mod1
    marshal_equal(o) { |obj| obj.kind_of? Mod1 }
    o = String.new
    o.extend Module.new
    assert_raises(TypeError) { marshaltest(o) }
    o = String.new
    o.extend Mod1
    o.extend Mod2
    marshal_equal(o) {|obj| class << obj; ancestors end}
  end

  def test_anonymous
    c = Class.new
    assert_raises(TypeError) { marshaltest(c) }
    o = c.new
    assert_raises(TypeError) { marshaltest(o) }
    m = Module.new
    assert_raises(TypeError) { marshaltest(m) }
  end

  def test_string_empty
    marshal_equal("")
  end

  def test_string_crlf
    marshal_equal("\r\n")
  end

  def test_string_escape
    marshal_equal("\0<;;>\1;;")
  end

  MyStruct2 = Struct.new(:a, :b)
  def test_struct_toplevel
    marshal_equal(MyStruct2.new(1,2))
  end
end


class TestMarshal < Test::Unit::TestCase
  include MarshalTestLib

  def fact(n)
    return 1 if n == 0
    f = 1
    while n>0
      f *= n
      n -= 1
    end
    return f
  end

  StrClone=String.clone;

  def test_marshal
    $x = [1,2,3,[4,5,"foo"],{1=>"bar"},2.5,fact(30)]
    $y = Marshal.dump($x)
    assert_equal($x, Marshal.load($y))

    assert_instance_of(StrClone, Marshal.load(Marshal.dump(StrClone.new("abc"))))

    [[1,2,3,4], [81, 2, 118, 3146]].each { |w,x,y,z|
      a = (x.to_f + y.to_f / z.to_f) * Math.exp(w.to_f / (x.to_f + y.to_f / z.to_f))
      ma = Marshal.dump(a)
      b = Marshal.load(ma)
      assert_equal(a, b)
    }
  end
end
