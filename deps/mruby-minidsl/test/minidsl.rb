class Klass < MiniDSL
  field :foo,  :t => String
  field :bar,  :t => String, :as     => :baz
  field :qux,  :t => Array , :freeze => true
  field :quux, :t => Fixnum, :load   => Proc.new { |a| a.reduce(0) { |n, m| m += n } }
end

assert("MiniDSL.field") do
  assert_true  Klass.method_defined?(:foo)
  assert_false Klass.method_defined?(:bar)
  assert_true  Klass.method_defined?(:baz)
  assert_true  Klass.method_defined?(:qux)
  assert_true  Klass.method_defined?(:quux)
end

assert("MiniDSL.fields") do
  t = Klass.fields
  assert_equal({ :t => String }, t[:foo])
  assert_equal({ :t => String, :as => :baz }, t[:bar])
  assert_equal({ :t => Array, :freeze => true }, t[:qux])
  # XXX, :quux
end

[:decode, :new].each do |m|
  assert("MiniDSL.#{ m }") do
    t = Klass.send(m, foo: "foo", bar: "bar", qux: ["cat", "dog"], quux: [1, 2, 3])
    # foo
    assert_equal("foo", t.foo)
    # bar
    assert_raise(NoMethodError) { t.bar }
    assert_equal("bar", t.baz)
    # qux
    assert_equal(["cat", "dog"], t.qux)
    assert_true(t.qux.frozen?)
    # quux
    assert_equal(6, t.quux)
  end
end

assert("MiniDSL#to_h") do
  t = Klass.new(foo: "foo", bar: "bar", qux: ["cat", "dog"], quux: [1, 2, 3]).to_h
  # foo
  assert_equal("foo", t[:foo])
  # bar
  assert_equal("bar", t[:bar])
  assert_nil(t[:baz])
  # qux
  assert_equal(["cat", "dog"], t[:qux])
  assert_true(t[:qux].frozen?)
  # quux
  assert_equal(6, t[:quux])
end

assert("MiniDSL#==") do
  t = Klass.new(foo: "foo", bar: "bar", qux: ["cat", "dog"], quux: [1, 2, 3])
  u = Klass.new(foo: "foo", bar: "bar", qux: ["cat", "dog"], quux: [1, 2, 3])
  assert_true(t == u)
end
