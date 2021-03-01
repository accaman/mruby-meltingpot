class TestApp < MTest::Unit::TestCase
  VALID_YML = <<EOT
version: 1

spec:
  log_device: /dev/null

  access_token_time_to_live: 1
EOT

  INVALID_YML = <<EOT
version: 1

spec:
  redis_db: scott
EOT

  REQUEST_ID_LEN   = SecureRandom.uuid.length
  ACCESS_TOKEN_LEN = SecureRandom.base64( 24 ).length

  def test_parse_yml
    valid_yml = Tempfile.new( "config.yml" )
    File.open( valid_yml.path, "w" ) { |handle| handle.write VALID_YML }
    assert( MeltingPot::ConfigParser.parse_yml( valid_yml.path ) )

    invalid_yml = Tempfile.new( "config.yml" )
    File.open( invalid_yml.path, "w" ) { |handle| handle.write INVALID_YML }
    assert_raise( RuntimeError ) { MeltingPot::ConfigParser.parse_yml( invalid_yml.path ) }
  ensure
    File.delete( valid_yml.path )
    File.delete( invalid_yml.path )
  end

  def test_initialize
    assert( app )
  end

  def test_rest_api_proxy_call_ok
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

    status, headers, body = *Rack::MockRequest.new(app).get("https://example.org/echo", {
      "HTTP_HOST" => "example.org",
      "HTTP_AUTHORIZATION" => "Bearer #{ token.access_token }"
    })

    # check status
    assert_equal( 200, status )
    # check request headers
    assert( headers["X-REQUEST-ID"] )
    assert( headers["x-fallthru-set-X-REQUEST-ID"] )
  ensure
    access_token_repository.delete( token.access_token ).join
    route_repository.delete( route.source ).join
  end

  def test_any_proxy_call_ok
    # before:
    user = MeltingPot::User.create( 
      "smith",
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

    # XXX, cannot use mock, because response body is not iterable or stringify
    status, headers, body = *Rack::MockRequest.new(app).post("https://example.org/echo", {
      Rack::REQUEST_METHOD => Rack::POST,
      "HTTP_HOST" => "example.org",
      "rack.input" => StringIO.new("username=smith&password=P@ssw0rd") 
    })

    # check status
    assert_equal( 200, status )
    # check request headers
    assert( headers["X-REQUEST-ID"] )
    assert( headers["x-fallthru-set-X-REQUEST-ID"] )
  ensure
    user_repository.delete( user.username ).join
    route_repository.delete( route.source ).join
  end

  def app
    valid_yml = Tempfile.new( "config.yml" )
    File.open( valid_yml.path, "w" ) { |handle| handle.write VALID_YML }
    MeltingPot::App.create(valid_yml.path, :redis_class => MeltingPot::TestRedis, :http_class => MeltingPot::TestHTTP) 
  ensure
    File.delete( valid_yml.path )
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end

  def access_token_repository
    @access_token_repository ||= MeltingPot::AccessTokenRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end

  def route_repository
    @route_repository ||= MeltingPot::RouteRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end
end
MTest::Unit.new.run
