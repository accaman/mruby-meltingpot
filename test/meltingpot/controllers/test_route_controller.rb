class TestRouteController < MTest::Unit::TestCase
  def test
    # test create
    req = Rack::Request.new(Rack::MockRequest.env_for("https://example.org/users", {
       Rack::REQUEST_METHOD => Rack::POST,
       Rack::RACK_INPUT => StringIO.new(
         "source=example.org" \
         + "&destination=192.0.2.0" \
         + "&auth_required=true"
       ),
       "HTTP_HOST" => "example.org"
    }))
    status, headers, body = *route_controller.create(req)
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify({ :source => "example.org", :destination => "192.0.2.0", :scheme => nil, :auth_required => true })

    assert_equal(201, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal(exp_data.length, headers["Content-Length"].to_i)
    assert_equal(exp_data, act_data)

    # test show in case of user exist
    status, headers, body = *route_controller.show("example.org")
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify({ :source => "example.org", :destination => "192.0.2.0", :scheme => nil, :auth_required => true })

    assert_equal(200, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal(exp_data.length, headers["Content-Length"].to_i)
    assert_equal(exp_data, act_data)

    # test delete
    status, headers, body = *route_controller.destroy("example.org")
    assert_equal(204, status)
    assert_equal({} , headers)
    assert_equal([] , body)

    # test show in case of user does not exist
    status, headers, body = *route_controller.show("example.org")
    act_data = ""; body.each { |chunk| act_data << chunk }
    exp_data = JSON.stringify({ "message" => "Not Found" })

    assert_equal(404, status)
    assert_equal("application/json; charset=utf-8", headers["Content-Type"])
    assert_equal(exp_data.length, headers["Content-Length"].to_i)
    assert_equal(exp_data, act_data)
  end

  def route_controller
    @route_controller ||= MeltingPot::RouteController.new(route_interactor, Logger.new(File::NULL))
  end

  def route_interactor
    @route_interactor ||= MeltingPot::RouteInteractor.new(route_repository, MeltingPot::Route, Logger.new(File::NULL))
  end

  def route_repository
    @route_repository ||= MeltingPot::RouteRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end
end
MTest::Unit.new.run
