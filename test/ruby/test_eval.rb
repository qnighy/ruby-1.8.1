require 'test/unit'

$KCODE = 'none'

class TestEval < Test::Unit::TestCase
  # eval with binding
  def test_ev
    local1 = "local1"
    lambda {
      local2 = "local2"
      return binding
    }.call
  end

  def test_eval
    assert_nil(eval(""))
    $bad=false
    eval 'while false; $bad = true; print "foo\n" end'
    assert(!$bad)

    assert(eval('TRUE'))
    assert(eval('true'))
    assert(!eval('NIL'))
    assert(!eval('nil'))
    assert(!eval('FALSE'))
    assert(!eval('false'))

    $foo = 'assert(true)'
    begin
      eval $foo
    rescue
      assert(false)
    end

    assert_equal('assert(true)', eval("$foo"))
    assert_equal(true, eval("true"))
    i = 5
    assert(eval("i == 5"))
    assert_equal(5, eval("i"))
    assert(eval("defined? i"))

    $x = test_ev
    assert_equal("local1", eval("local1", $x)) # normal local var
    assert_equal("local2", eval("local2", $x)) # nested local var
    $bad = true
    begin
      p eval("local1")
    rescue NameError		# must raise error
      $bad = false
    end
    assert(!$bad)

    # !! use class_eval to avoid nested definition
    self.class.class_eval %q(
      module EvTest
	EVTEST1 = 25
	evtest2 = 125
	$x = binding
      end
    )
    assert_equal(25, eval("EVTEST1", $x))	# constant in module
    assert_equal(125, eval("evtest2", $x))	# local var in module
    $bad = true
    begin
      eval("EVTEST1")
    rescue NameError		# must raise error
      $bad = false
    end
    assert(!$bad)

    x = proc{}
    eval "i4 = 1", x
    assert_equal(1, eval("i4", x))
    x = proc{proc{}}.call
    eval "i4 = 22", x
    assert_equal(22, eval("i4", x))
    $x = []
    x = proc{proc{}}.call
    eval "(0..9).each{|i5| $x[i5] = proc{i5*2}}", x
    assert_equal(8, $x[4].call)

    x = binding
    eval "i = 1", x
    assert_equal(1, eval("i", x))
    x = proc{binding}.call
    eval "i = 22", x
    assert_equal(22, eval("i", x))
    $x = []
    x = proc{binding}.call
    eval "(0..9).each{|i5| $x[i5] = proc{i5*2}}", x
    assert_equal(8, $x[4].call)
    x = proc{binding}.call
    eval "for i6 in 1..1; j6=i6; end", x
    assert(eval("defined? i6", x))
    assert(eval("defined? j6", x))

    proc {
      p = binding
      eval "foo11 = 1", p
      foo22 = 5
      proc{foo11=22}.call
      proc{foo22=55}.call
      assert_equal(eval("foo11"), eval("foo11", p))
      assert_equal(1, eval("foo11"))
      assert_equal(eval("foo22"), eval("foo22", p))
      assert_equal(55, eval("foo22"))
    }.call

    p1 = proc{i7 = 0; proc{i7}}.call
    assert_equal(0, p1.call)
    eval "i7=5", p1
    assert_equal(5, p1.call)
    assert(!defined?(i7))

    p1 = proc{i7 = 0; proc{i7}}.call
    i7 = nil
    assert_equal(0, p1.call)
    eval "i7=1", p1
    assert_equal(1, p1.call)
    eval "i7=5", p1
    assert_equal(5, p1.call)
    assert_nil(i7)
  end
end
