class TestProxyInteractor < MTest::Unit::TestCase
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

    result = rest_api_proxy_interactor.proxy_pass(
      MeltingPot::ProxyController::RestApiContext.new("Bearer", token.access_token),
      "https://example.org/echo"
    )
    status, headers, body, verified_user_id = result.status, result.headers, result.body, result.verified_user_id
    # check status
    assert_equal( 200, status )

    # check request headers
    assert_equal( "https", headers["X-FORWARDED-PROTO"] )
    assert_equal( "example.org", headers["X-FORWARDED-HOST"] )
    assert_equal( "192.0.2.0", headers["HOST"] )
    assert_equal( "johndoe", headers["X-USER-ID"] )

    # check response headers
    # assert_equal( "", headers["x-fallthru-set-RTT"] )
    assert_equal( "johndoe", headers["x-fallthru-set-X-USER-ID"] )

    # check user id
    assert_equal( "johndoe", verified_user_id )
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

    assert_raise( MeltingPot::NotFoundError ) do
      rest_api_proxy_interactor.proxy_pass(
        MeltingPot::ProxyController::RestApiContext.new("Bearer", token.access_token),
        "https://mruby.org/echo"
      )
    end
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

    assert_raise( MeltingPot::UnauthorizedError ) do
      rest_api_proxy_interactor.proxy_pass(
        MeltingPot::ProxyController::RestApiContext.new("Bearer", "foobarbazqux"),
        "https://example.org/echo"
      )
    end
  ensure
    access_token_repository.delete( token.access_token ).join
    route_repository.delete( route.source ).join
  end

  def test_any_proxy_pass_ok_1
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

    result = any_proxy_interactor.proxy_pass(
      MeltingPot::ProxyController::AnyContext.new(user.username, "P@ssw0rd", false),
      "https://example.org/echo",
      "POST",
      {
        "HOST" => "example.org"
      },
      StringIO.new("username=#{ user.username }&password=P@ssw0rd") 
    )
    status, headers, body, verified_user_id = result.status, result.headers, result.body, result.verified_user_id
    # check status
    assert_equal( 200, status )

    # check request headers
    assert_equal( "https", headers["X-FORWARDED-PROTO"] )
    assert_equal( "example.org", headers["X-FORWARDED-HOST"] )
    assert_equal( "192.0.2.0", headers["HOST"] )
    assert_equal( "johndoe", headers["X-USER-ID"] )

    # check response haeders
    # assert_equal( "", headers["x-fallthru-set-RTT"] )
    assert_equal( "johndoe", headers["x-fallthru-set-X-USER-ID"] )

    # check user id
    assert_equal( "johndoe", verified_user_id )
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def test_any_proxy_pass_ok_2
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

    result = any_proxy_interactor.proxy_pass(
      MeltingPot::ProxyController::AnyContext.new(user.username, nil, true),
      "https://example.org/echo",
      "POST",
      {
        "HOST" => "example.org"
      }
    )
    status, headers, body, verified_user_id = result.status, result.headers, result.body, result.verified_user_id
    # check status
    assert_equal( 200, status )

    # check request headers
    assert_equal( "https", headers["X-FORWARDED-PROTO"] )
    assert_equal( "example.org", headers["X-FORWARDED-HOST"] )
    assert_equal( "192.0.2.0", headers["HOST"] )
    assert_equal( "johndoe", headers["X-USER-ID"] )
    
    # check response headers
    # assert_equal( "", headers["x-fallthru-set-RTT"] )
    assert_equal( "johndoe", headers["x-fallthru-set-X-USER-ID"] )

    # check user id
    assert_equal( "johndoe", verified_user_id )
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

    assert_raise( MeltingPot::NotFoundError ) do
      any_proxy_interactor.proxy_pass(
        MeltingPot::ProxyController::AnyContext.new(user.username, "P@ssw0rd", false),
        "https://mruby.org/echo",
        "POST",
        {
          "HOST" => "mruby.org"
        },
        StringIO.new("username=#{ user.username }&password=P@ssw0rd") 
      )
    end
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

    assert_raise( MeltingPot::BadRequestError ) do
      any_proxy_interactor.proxy_pass(
        MeltingPot::ProxyController::AnyContext.new("", nil, false),
        "https://example.org/echo",
        "POST",
        {
          "HOST" => "example.org"
        },
        StringIO.new("id=#{ user.username }") 
      )
    end
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def test_rest_api_proxy_pass_unauthorized_1
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

    assert_raise( MeltingPot::UnauthorizedError ) do
      any_proxy_interactor.proxy_pass(
        MeltingPot::ProxyController::AnyContext.new("janedoe", "P@ssw0rd", false),
        "https://example.org/echo",
        "POST",
        {
          "HOST" => "example.org"
        },
        StringIO.new("username=janedoe&password=P@ssw0rd") 
      )
    end
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def test_rest_api_proxy_pass_unauthorized_2
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

    assert_raise( MeltingPot::UnauthorizedError ) do
      any_proxy_interactor.proxy_pass(
        MeltingPot::ProxyController::AnyContext.new(user.username, "password", false),
        "https://example.org/echo",
        "POST",
        {
          "HOST" => "example.org"
        },
        StringIO.new("username=#{ user.username }&password=password") 
      )
    end
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  # Helpers
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