class TestAdminApp < MTest::Unit::TestCase
  PASSWORD_PEPPER = SecureRandom.hex(32)

  VALID_YML = <<EOT
version: 1

spec:
  log_device: /dev/null

  access_token_time_to_live: 1

  password_pepper: #{ PASSWORD_PEPPER }
EOT

  INVALID_YML = <<EOT
version: 1

spec:
  redis_db: scott
EOT

  REQUEST_ID_LEN   = SecureRandom.uuid.length
  ACCESS_TOKEN_LEN = SecureRandom.base64(24).length

  def test_user_create
    status, headers, body = *Rack::MockRequest.new(app).post("/users", {
      Rack::RACK_INPUT => StringIO.new(
        "username=johndoe" \
        + "&password=P@ssw0rd123456789" 
      ),
      "HTTP_HOST" => "example.org"
    })
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify({ "username" => "johndoe" })

    assert_equal(201, status)
    assert_equal(REQUEST_ID_LEN, headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN, headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal(exp_data, act_data)      
  ensure
    user_repository.delete("johndoe").join
  end

  def test_user_show
    user = MeltingPot::User.create("johndoe", "P@ssw0rd123456789#{ PASSWORD_PEPPER }")
    user_repository.create(user).join

    status, headers, body = *Rack::MockRequest.new(app).get("/users/johndoe", {
      "HTTP_HOST" => "example.org"
    })
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify({ "username" => "johndoe" })

    assert_equal(200, status)
    assert_equal(REQUEST_ID_LEN, headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN, headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal(exp_data, act_data)
  ensure
    user_repository.delete("johndoe").join
  end

  def test_user_delete
    user = MeltingPot::User.create("johndoe", "P@ssw0rd123456789#{ PASSWORD_PEPPER }")
    user_repository.create(user).join
    
    status, headers, body = *Rack::MockRequest.new(app).delete("/users/johndoe", {
      "HTTP_HOST" => "example.org"
    })

    assert_equal(204, status)
    assert_equal(REQUEST_ID_LEN, headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN, headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal(body, [])
  end

  def test_access_token_grant
    user = MeltingPot::User.create("johndoe", "P@ssw0rd123456789#{ PASSWORD_PEPPER }")
    user_repository.create(user).join

    status, headers, body = *Rack::MockRequest.new(app).post("/token", {
      Rack::RACK_INPUT => StringIO.new(
        "username=johndoe" \
        + "&password=P@ssw0rd123456789" \
        + "&grant_type=password" 
      ),
      "HTTP_HOST" => "example.org"
    })
    data = ""; body.each { |chunk| data << chunk }
    data = JSON.parse(data)

    assert_equal(200, status)
    assert_equal(REQUEST_ID_LEN , headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN , headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal("Bearer", data["token_type"])
    assert_equal(1, data["expires_in"])
    assert_equal(ACCESS_TOKEN_LEN, data["access_token"].length)     
  ensure
    user_repository.delete("johndoe").join
  end

  def test_route_create
    status, headers, body = *Rack::MockRequest.new(app).post("/routes", {
      Rack::RACK_INPUT => StringIO.new(
        "source=example.org" \
        + "&destination=192.0.2.0" \
        + "&auth_required=true"
      ),
      "HTTP_HOST" => "example.org"
    })
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify({ :source => "example.org", :destination => "192.0.2.0", :scheme => nil, :auth_required => true })

    assert_equal(201, status)
    assert_equal(REQUEST_ID_LEN, headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN, headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal(exp_data, act_data)      
  ensure
    route_repository.delete("example.org").join
  end

  def test_route_show
    exp = MeltingPot::Route.new(:source => "example.org", :destination => "192.0.2.0", :scheme => nil, :auth_required => true)
    route_repository.create(exp).join

    status, headers, body = *Rack::MockRequest.new(app).get("/routes/#{ exp.source }", {
      "HTTP_HOST" => "example.org"
    })
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify(exp.to_h)

    assert_equal(200, status)
    assert_equal(REQUEST_ID_LEN, headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN, headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal(exp_data, act_data)
  ensure
    route_repository.delete(exp.source).join
  end

  def test_route_delete
    exp = MeltingPot::Route.new(:source => "example.org", :destination => "192.0.2.0", :scheme => nil, :auth_required => true)
    route_repository.create(exp).join
    
    status, headers, body = *Rack::MockRequest.new(app).delete("/routes/#{ exp.source }", {
      "HTTP_HOST" => "example.org"
    })

    assert_equal(204, status)
    assert_equal(REQUEST_ID_LEN, headers["X-Request-Id"].length)
    assert_equal(REQUEST_ID_LEN, headers["x-fallthru-set-X-REQUEST-ID"].length)
    assert_equal(body, [])
  end

  def app
    valid_yml = Tempfile.new("config.yml")
    File.open(valid_yml.path, "w") { |handle| handle.write VALID_YML }
    MeltingPot::AdminApp.create(valid_yml.path, :redis_class => MeltingPot::TestRedis) 
  ensure
    File.delete(valid_yml.path)
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
