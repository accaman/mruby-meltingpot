class TestRackSessionRedis < MTest::Unit::TestCase
  def test
    counter = Proc.new { |env|
      req = Rack::Request.new(env)
      req.session["count"] ||= 0
      req.session["count"] += 1
      [200, {}, ["You visit: #{ req.session['count'] }"]]
    }
    app = Rack::Session::Redis.new(
      counter, 
      {
        :key => "sid",
        :domain => "example.com",
        :path => "/",
        :expire_after => 0,
        :cache => Rack::Session::Redis::TestRedis.new("127.0.0.1", 6379)
      }
    )

    # created the session:
    headers = Rack::MockRequest.new(app).get('/').headers
    cookies = Rack::Utils.parse_query(headers["Set-Cookie"], ";") { |str| Rack::Utils.unescape(str) }

    assert_match(/[0-9a-f]{64}/, cookies["sid"])
    assert_equal("example.com", cookies["domain"])
    assert_equal("/", cookies["path"])
    assert_match(/..., \d\d ... \d\d\d\d \d\d:\d\d:\d\d .../, cookies["expires"])

    data = app.get_session({}, cookies["sid"])[1]
    assert_equal(1, data["count"])

    # updated the session:
    Rack::MockRequest.new(app).get('/', Rack::HTTP_COOKIE => "sid=#{ cookies["sid"] }").headers
    data = app.get_session({}, cookies["sid"])[1]
    assert_equal(2, data["count"])

    # expired the session:
    Sleep::sleep(1)

    old_sid = cookies["sid"]
    headers = Rack::MockRequest.new(app).get("/", Rack::HTTP_COOKIE => "sid=#{ old_sid }").headers
    cookies = Rack::Utils.parse_query(headers["Set-Cookie"], ";") { |str| Rack::Utils.unescape(str) }

    new_sid = cookies["sid"]
    assert_not_equal(old_sid, new_sid)

    data = app.get_session({}, new_sid)[1]
    assert_equal(1, data["count"])
  end
end

MTest::Unit.new.run
