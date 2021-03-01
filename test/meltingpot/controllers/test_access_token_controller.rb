class TestAccessTokenController < MTest::Unit::TestCase
  def test_grant
    user = MeltingPot::User.create("johndoe", "P@ssw0rd123456789#{ PASSWORD_PEPPER }")
    user_repository.create(user).join

    # ok
    req = Rack::Request.new(Rack::MockRequest.env_for( "https://example.org/token", {
      Rack::REQUEST_METHOD => Rack::POST,
      Rack::RACK_INPUT => StringIO.new(
        "username=johndoe" \
        + "&password=P@ssw0rd123456789" \
        + "&grant_type=password"
      ),
      "HTTP_HOST" => "example.org"
    }))
    status, headers, body = *access_token_controller.grant(req)
    data = ""; body.each { |chunk| data << chunk }
    json = JSON.parse( data )

    assert_equal(200, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal("no-store", headers["Cache-Control"])
    assert_equal("no-cache", headers["Pragma"])
    assert_equal(1, json["expires_in"])
    assert_equal("Bearer", json["token_type"])
    assert(json["access_token"])

    # bad request
    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/token", {
      Rack::REQUEST_METHOD => Rack::POST,
      Rack::RACK_INPUT => StringIO.new(
        "username=johndoe" \
        + "&password=P@ssw0rd123456789" \
        + "&grant_type=authorization_code"
      ),
      "HTTP_HOST" => "example.org"
    }))
    status, headers, body = *access_token_controller.grant(req)
    data = ""; body.each { |chunk| data << chunk }
    json = JSON.parse( data )

    assert_equal(400, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal("no-store", headers["Cache-Control"])
    assert_equal("no-cache", headers["Pragma"])
    assert_equal("invalid_client", json["error"])
    assert_equal("unsupported grant type: authorization_code", json["error_description"])

    # bad request
    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/token", {
      Rack::REQUEST_METHOD => Rack::POST,
      Rack::RACK_INPUT => StringIO.new(
        "username=johndoe" \
        + "&grant_type=password"
      ),
      "HTTP_HOST" => "example.org"
    }))
    status, headers, body = *access_token_controller.grant(req)
    data = ""; body.each { |chunk| data << chunk }
    json = JSON.parse( data )

    assert_equal(400, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal("no-store", headers["Cache-Control"])
    assert_equal("no-cache", headers["Pragma"])
    assert_equal("invalid_request", json["error"])
    assert_equal("Validation Failed: [missing parameter (password)]", json["error_description"])

    # bad request
    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/token", {
      Rack::REQUEST_METHOD => Rack::POST,
      Rack::RACK_INPUT => StringIO.new(
        "username=johndoe" \
        + "&password=P@ssw0rd" \
        + "&grant_type=password"
      ),
      "HTTP_HOST" => "example.org"
    }))
    status, headers, body = *access_token_controller.grant(req)
    data = ""; body.each { |chunk| data << chunk }
    json = JSON.parse( data )

    assert_equal(400, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal("no-store", headers["Cache-Control"])
    assert_equal("no-cache", headers["Pragma"])
    assert_equal("invalid_client", json["error"])
    assert_equal("Authorization Failed", json["error_description"])
  ensure
    user_repository.delete( user.username ).join
  end

  PASSWORD_PEPPER = SecureRandom.hex(32)

  def access_token_controller
    @access_token_controller ||= MeltingPot::AccessTokenController.new(access_token_interactor)
  end

  def access_token_interactor
    @access_token_interactor ||= MeltingPot::AccessTokenInteractor.new(access_token_repository, user_repository, MeltingPot::BearerToken, 1, PASSWORD_PEPPER, ::Logger.new(File::NULL))
  end

  def access_token_repository
    @access_token_repository ||= MeltingPot::AccessTokenRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end
end
MTest::Unit.new.run
