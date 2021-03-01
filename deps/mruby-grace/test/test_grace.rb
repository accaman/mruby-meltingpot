class TestGrace < MTest::Unit::TestCase
  class HelloGrace < Grace
    get "/" do
      [ 200, {}, ["Hello Grace\n"] ]
    end
  end

  class Greeter < Grace
    get "/users/{name}" do |name|
      [ 200, {}, ["Hello #{name}\n"] ]
    end
  end

  def env_for(uri = '', opts = {})
    env = {}

    env["REQUEST_METHOD"]  = opts[:method] ? opts[:method].to_s.upcase : "GET"
    env["SERVER_NAME"]     = 'example.org'
    env["SERVER_PORT"]     = '80'
    env["QUERY_STRING"]    = ''
    env["PATH_INFO"]       = uri
    env["RACK_URL_SCHEME"] = 'http'
    env["HTTPS"]           = env["rack.url_scheme"] == 'https' ? 'on' : 'off'
    env["SCRIPT_NAME"]     = opts[:script_name] || ''

    env
  end

  def test_initialize
    assert( HelloGrace.new )
  end

  %i(GET POST PUT DELETE PATCH HEAD OPTIONS).each do |m|
    define_method("test_#{ m.downcase }_request") do
      klass = Class.new(Grace) do
        send m.downcase, "/" do
          [ 200, {}, ["#{ m } /\n"] ]
        end
      end
      assert_equal ["#{ m } /\n"], klass.new.call( env_for("/", :method => m) )[2]
    end
  end

  def test_parameterized_request
    assert_equal ["Hello john\n"], Greeter.new.call( env_for("/users/john") )[2]
  end

  def test_route_missing!
    assert_raise(Grace::NotFound) { HelloGrace.new.call( env_for("/", :method => "PROPFIND") ) }
    assert_raise(Grace::NotFound) { HelloGrace.new.call( env_for("/users/john") ) }
  end

  def test_forward
    assert_equal "Hello, Downstream\n", HelloGrace.new(Proc.new { [200, {}, "Hello, Downstream\n"] }).call( env_for("/users/john") )[2]
    assert_raise(RuntimeError) { HelloGrace.new(200).call( env_for("/users/john") ) }
  end

  def test_use_env_in_callback
    klass = Class.new Grace do
      get "/requests" do
        [200, {}, ["#{ env["REQUEST_METHOD"] } #{ env["SCRIPT_NAME"] }#{ env["PATH_INFO"] }\n"]]
      end
    end
    assert_equal ["GET /requests\n"], klass.new.call( env_for("/requests") )[2]
  end
end

MTest::Unit.new.run
