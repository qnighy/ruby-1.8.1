require 'drbtest'

class TestDRbCore < Test::Unit::TestCase
  include DRbCore
end

class TestDRbYield < Test::Unit::TestCase
  def setup
    @ext = DRbService.manager.service('ut_drb.rb')
    @there = @ext.front
  end

  def teardown
    @ext.stop_service
  end

  def test_01_one
    @there.echo_yield_1([]) {|one|
      assert_equal([], one)
    }
    
    @there.echo_yield_1(1) {|one|
      assert_equal(1, one)
    }
    
    @there.echo_yield_1(nil) {|one|
      assert_equal(nil, one)
    }
  end

  def test_02_two
    @there.echo_yield_2([], []) {|one, two|
      assert_equal([], one)
      assert_equal([], two)
    }

    @there.echo_yield_2(1, 2) {|one, two|
      assert_equal(1, one)
      assert_equal(2, two)
    }

    @there.echo_yield_2(3, nil) {|one, two|
      assert_equal(3, one)
      assert_equal(nil, two)
    }

    @there.echo_yield_1([:key, :value]) {|one, two|
      assert_equal(:key, one)
      assert_equal(:value, two)
    }
  end

  def test_03_many
    @there.echo_yield_0 {|*s|
      assert_equal([], s)
    }
    @there.echo_yield(nil) {|*s|
      assert_equal([nil], s)
    }
    @there.echo_yield(1) {|*s|
      assert_equal([1], s)
    }
    @there.echo_yield(1, 2) {|*s|
      assert_equal([1, 2], s)
    }
    @there.echo_yield(1, 2, 3) {|*s|
      assert_equal([1, 2, 3], s)
    }
    @there.echo_yield([], []) {|*s|
      assert_equal([[], []], s)
    }
    @there.echo_yield([]) {|*s|
      assert_equal([[]], s) # !
    }
  end

  def test_04_many_to_one
    @there.echo_yield_0 {|*s|
      assert_equal([], s)
    }
    @there.echo_yield(nil) {|*s|
      assert_equal([nil], s)
    }
    @there.echo_yield(1) {|*s|
      assert_equal([1], s)
    }
    @there.echo_yield(1, 2) {|*s|
      assert_equal([1, 2], s)
    }
    @there.echo_yield(1, 2, 3) {|*s|
      assert_equal([1, 2, 3], s)
    }
    @there.echo_yield([], []) {|*s|
      assert_equal([[], []], s)
    }
    @there.echo_yield([]) {|*s|
      assert_equal([[]], s)
    }
  end

  def test_05_array_subclass
    @there.xarray_each {|x| assert_kind_of(XArray, x)}
    @there.xarray_each {|*x| assert_kind_of(XArray, x[0])}
  end
end

class TestRubyYield < TestDRbYield
  def echo_yield(*arg)
    yield(*arg)
  end

  def echo_yield_0
    yield
  end

  def echo_yield_1(a)
    yield(a)
  end

  def echo_yield_2(a, b)
    yield(a, b)
  end

  def xarray_each
    xary = [XArray.new([0])]
    xary.each do |x|
      yield(x)
    end
  end

  def setup
    @there = self
  end
  
  def teardown
  end
end

class TestRuby18Yield < TestRubyYield
  class YieldTest18
    def echo_yield(*arg, &proc)
      proc.call(*arg)
    end
    
    def echo_yield_0(&proc)
      proc.call
    end
    
    def echo_yield_1(a, &proc)
      proc.call(a)
    end
    
    def echo_yield_2(a, b, &proc)
      proc.call(a, b)
    end

    def xarray_each(&proc)
      xary = [XArray.new([0])]
      xary.each(&proc)
    end

  end

  def setup
    @there = YieldTest18.new
  end
end

class TestDRbAry < Test::Unit::TestCase
  include DRbAry
end

class TestDRbMServer < Test::Unit::TestCase
  def setup
    @ext = DRbService.manager.service('ut_drb.rb')
    @there = @ext.front
    @server = (1..3).collect do |n|
      DRb::DRbServer.new(nil, Onecky.new(n.to_s))
    end
  end

  def teardown
    @server.each do |s|
      s.stop_service
    end
    @ext.stop_service
  end

  def test_01
    assert_equal(6, @there.sample(@server[0].front, @server[1].front, @server[2].front))
  end
end

class TestDRbReusePort < TestDRbAry
  def setup
    sleep 1
    @ext = DRbService.manager.service('ut_port.rb')
    @there = @ext.front
  end
end

class TestDRbSafe1 < TestDRbAry
  def setup
    sleep 1
    @ext = DRbService.manager.service('ut_safe1.rb')
    @there = @ext.front
  end
end

class TestDRbEval < Test::Unit::TestCase
  def setup
    super
    sleep 1
    @ext = DRbService.manager.service('ut_eval.rb')
    @there = @ext.front
  end

  def teardown
    @ext.stop_service
  end
  
  def test_01_safe1_eval
    assert_raises(SecurityError) do
      @there.method_missing(:instance_eval, 'ENV.inspect')
    end

    assert_raises(SecurityError) do
      @there.method_missing(:send, :eval, 'ENV.inspect')
    end

    remote_class = @there.remote_class

    assert_raises(SecurityError) do
      remote_class.class_eval('ENV.inspect')
    end

    assert_raises(SecurityError) do
      remote_class.module_eval('ENV.inspect')
    end
  end
end

class TestDRbLarge < Test::Unit::TestCase
  def setup
    sleep 1
    @ext = DRbService.manager.service('ut_large.rb')
    @there = @ext.front
  end

  def teardown
    @ext.stop_service
  end

  def test_01_large_ary
    ary = [2] * 10240
    assert_equal(10240, @there.size(ary))
    assert_equal(20480, @there.sum(ary))
  end

  def test_02_large_ary
    ary = ["Hello, World"] * 10240
    assert_equal(10240, @there.size(ary))
  end

  def test_03_large_ary
    ary = [Thread.current] * 10240
    assert_equal(10240, @there.size(ary))
  end

  def test_04_many_arg
    assert_raises(ArgumentError) {
      @there.arg_test(1, 2, 3, 4, 5, 6, 7, 8, 9, 0)
    }
  end

  def test_05_too_large_ary
    ary = ["Hello, World"] * 102400
    exception = nil
    begin
      @there.size(ary)      
    rescue StandardError
      exception = $!
    end
    assert_kind_of(StandardError, exception)
  end
end
