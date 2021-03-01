class TestUserController < MTest::Unit::TestCase
  def test
    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/users", {
       Rack::REQUEST_METHOD => Rack::POST,
       Rack::RACK_INPUT => StringIO.new(
         "username=johndoe" \
         + "&password=P@ssw0rd123456789" 
       ),
       "HTTP_HOST" => "example.org"
    }))
    status, headers, body = *user_controller.create(req)
    act_data = ""; body.each { |chunk| act_data << chunk }

    exp_data = JSON.stringify({ "username" => "johndoe" })
    exp_size = exp_data.size

    assert_equal(201, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal(exp_size, headers["Content-Length"].to_i)
    assert_equal(exp_data, act_data)

    # test show in case of user exists
    status, headers, body = *user_controller.show("johndoe")
    act_data = ""; body.each { |chunk| act_data << chunk }

    exp_data = JSON.stringify({ "username" => "johndoe" })
    exp_size = exp_data.size

    assert_equal(200, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal(exp_size, headers["Content-Length"].to_i)
    assert_equal(exp_data, act_data)

    # # test delete
    status, headers, body = *user_controller.destroy("johndoe")
    assert_equal(204, status)
    assert_equal({}, headers)
    assert_equal([], body)

    # test show in case of user does not exists
    status, headers, body = *user_controller.show("johndoe")
    act_data = ""; body.each { |chunk| act_data << chunk }

    exp_data = JSON.stringify( { "message" => "Not Found" } )
    exp_size = exp_data.size

    assert_equal(404, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal(exp_size, headers["Content-Length"].to_i)
    assert_equal(exp_data, act_data)
  end

  PASSWORD_PEPPER = SecureRandom.hex(32)

  def user_controller
    @user_interactor ||= MeltingPot::UserController.new(user_interactor, Logger.new(File::NULL))
  end

  def user_interactor
    @user_interactor ||= MeltingPot::UserInteractor.new(user_repository, MeltingPot::User, PASSWORD_PEPPER, Logger.new(File::NULL))
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end
end
MTest::Unit.new.run
