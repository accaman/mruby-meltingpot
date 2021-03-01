class TestProxyController < MTest::Unit::TestCase
  def test_rest_api_proxy_pass_ok
    # before:
    token = MeltingPot::BearerToken.new( 
      :access_token => SecureRandom.base64( 24 ),
      :token_type => "Bearer",
      :expires => Time.now + 3600,
      :user_id => "johndoe"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    access_token_repository.create( token ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/echo", {
      Rack::REQUEST_METHOD => Rack::GET,
      "HTTP_HOST" => "example.org",
      "HTTP_AUTHORIZATION" => "Bearer #{ token.access_token }"
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 200, status )
    # check request  headers
    assert_equal( "127.0.0.1", headers["X-FORWARDED-FOR"] )
    assert_nil( headers["AUTHORIZATION"] )
  ensure
    access_token_repository.delete( token.access_token ).join
    route_repository.delete( route.source ).join
  end

  def test_rest_api_proxy_pass_not_found
    # before:
    token = MeltingPot::BearerToken.new( 
      :access_token => SecureRandom.base64( 24 ),
      :token_type => "Bearer",
      :expires => Time.now + 3600,
      :user_id => "johndoe"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    access_token_repository.create( token ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://mruby.org/echo", {
      Rack::REQUEST_METHOD => Rack::GET,
      "HTTP_HOST" => "mruby.org",
      "HTTP_AUTHORIZATION" => "Bearer #{ token.access_token }"
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 404, status )
    # check body
    data = ""; body.each { |chunk| data << chunk }
    assert_equal( { "message" => "Not Found" }, JSON.parse( data ) )
  ensure
    access_token_repository.delete( token.access_token ).join
    route_repository.delete( route.source ).join
  end

  def test_rest_api_proxy_pass_unauthorized
    # before:
    token = MeltingPot::BearerToken.new( 
      :access_token => SecureRandom.base64( 24 ),
      :token_type => "Bearer",
      :expires => Time.now + 3600,
      :user_id => "johndoe"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    access_token_repository.create( token ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/echo", {
      Rack::REQUEST_METHOD => Rack::GET,
      "HTTP_HOST" => "example.org",
      "HTTP_AUTHORIZATION" => "Bearer foobarbazqux"
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 401, status )
    # check request  headers
    assert_equal( "no-store", headers["Cache-Control"] )
    assert_equal( "no-cache", headers["Pragma"] )
    # check body
    data = ""; body.each { |chunk| data << chunk }
    assert_equal( { "message" => "Unauthorized" }, JSON.parse( data ) )
  ensure
    access_token_repository.delete( token.access_token ).join
    route_repository.delete( route.source ).join
  end

  def test_any_proxy_pass_ok
    # before:
    user = MeltingPot::User.create( 
      "johndoe",
      "P@ssw0rd"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    user_repository.create( user ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/echo", {
      Rack::REQUEST_METHOD => Rack::POST,
      "HTTP_HOST" => "example.org",
      "rack.input" => StringIO.new("username=#{ user.username }&password=P@ssw0rd") 
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 200, status )
    # check request  headers
    assert_equal( "127.0.0.1", headers["X-FORWARDED-FOR"] )
    assert_nil( headers["AUTHORIZATION"] )
    # check session
    assert_equal( "johndoe", req.session["user_id"] )

    # XXX, session
    req.set_header("REQUEST_METHOD", "GET")
    req.set_header("rack.input", [])
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 200, status )
    # check request  headers
    assert_equal( "127.0.0.1", headers["X-FORWARDED-FOR"] )
    assert_nil( headers["AUTHORIZATION"] )
    # check session
    assert_equal( "johndoe", req.session["user_id"] )
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def test_any_proxy_pass_not_found
    # before:
    user = MeltingPot::User.create( 
      "johndoe",
      "P@ssw0rd"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    user_repository.create( user ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://mruby.org/echo", {
      Rack::REQUEST_METHOD => Rack::POST,
      "HTTP_HOST" => "mruby.org",
      "rack.input" => StringIO.new("username=#{ user.username }&password=P@ssw0rd") 
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 404, status )
    # check response headers
    assert_equal(File.join(@proxy_controller.static_dir, "/html/404.html"), headers["x-reproxy-url"])
    # check session
    assert_nil( req.session["user_id"] )
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def test_rest_api_proxy_bad_request
    # before:
    user = MeltingPot::User.create( 
      "johndoe",
      "P@ssw0rd"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    user_repository.create( user ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/echo", {
      Rack::REQUEST_METHOD => Rack::POST,
      "HTTP_HOST" => "example.org",
      "rack.input" => StringIO.new("id=#{ user.username }") 
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 400, status )
    # check response headers
    assert_equal(File.join(@proxy_controller.static_dir, "/html/400.html"), headers["x-reproxy-url"])
    # check session
    assert_nil( req.session["user_id"] )
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def test_rest_api_proxy_pass_unauthorized
    # before:
    user = MeltingPot::User.create( 
      "johndoe",
      "P@ssw0rd"
    )
    route = MeltingPot::Route.new(
      :source => "example.org",
      :destination => "192.0.2.0",
      :scheme => nil, # passthru
      :auth_required => true
    )
    user_repository.create( user ).join
    route_repository.create( route ).join

    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/echo", {
      Rack::REQUEST_METHOD => Rack::POST,
      "HTTP_HOST" => "example.org",
      "rack.input" => StringIO.new("username=janedoe&password=P@ssw0rd") 
    }))
    status, headers, body = *proxy_controller.proxy_pass(req)

    # check status
    assert_equal( 401, status )
    # check response headers
    assert_equal(File.join(@proxy_controller.static_dir, "/html/401.html"), headers["x-reproxy-url"])
    # check session
    assert_nil( req.session["user_id"] )
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  # Helpers
  def proxy_controller
    @proxy_controller ||= MeltingPot::ProxyController.new( rest_api_proxy_interactor, any_proxy_interactor, "/app/static", MeltingPot::Logger.new(File::NULL) )
  end

  def rest_api_proxy_interactor
    @rest_api_proxy_interactor ||= MeltingPot::RestApiProxyInteractor.new( access_token_repository, route_repository, MeltingPot::TestHTTP.new, MeltingPot::Logger.new(File::NULL) )
  end

  def any_proxy_interactor
    @any_api_proxy_interactor ||= MeltingPot::AnyProxyInteractor.new( user_repository, route_repository, MeltingPot::TestHTTP.new, MeltingPot::Logger.new(File::NULL) )
  end

  def access_token_repository
    @access_token_repository ||= MeltingPot::AccessTokenRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end

  def route_repository
    @route_repository ||= MeltingPot::RouteRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end
end
MTest::Unit.new.run