def marshal(env)
  env.map {|k, v| "#{k}:#{v}"}.join("\t")
end

def unmarshal(str)
  str.split("\t").map {|p| p.split(':', 2)}.to_h
end

app = Rack::Lint.new(lambda { |env|
  req = Rack::Request.new(env)

  env["mock.postdata"] = env["rack.input"].read
  if req.GET["error"]
    env["rack.errors"].puts req.GET["error"]
    env["rack.errors"].flush
  end

  body = req.head? ? "" : marshal(env)
  Rack::Response.new(body,
                     req.GET["status"] || 200,
                     "Content-Type" => "text/yaml").finish
})

describe Rack::MockRequest do
  it "return a MockResponse" do
    res = Rack::MockRequest.new(app).get("")
    res.must_be_kind_of Rack::MockResponse
  end

  it "be able to only return the environment" do
    env = Rack::MockRequest.env_for("")
    env.must_be_kind_of Hash
    env.must_include "rack.version"
  end

  it "return an environment with a path" do
    env = Rack::MockRequest.env_for("http://www.example.com/parse?location[]=1&location[]=2&age_group[]=2")
    env["QUERY_STRING"].must_equal "location[]=1&location[]=2&age_group[]=2"
    env["PATH_INFO"].must_equal "/parse"
    env.must_be_kind_of Hash
    env.must_include "rack.version"
  end

  it "provide sensible defaults" do
    res = Rack::MockRequest.new(app).request

    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "example.org"
    env["SERVER_PORT"].must_equal "80"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/"
    env["SCRIPT_NAME"].must_equal ""
    env["rack.url_scheme"].must_equal "http"
    env["mock.postdata"].must_be :empty?
  end

  it "allow GET/POST/PUT/DELETE/HEAD" do
    res = Rack::MockRequest.new(app).get("", :input => "foo")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"

    res = Rack::MockRequest.new(app).post("", :input => "foo")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "POST"

    res = Rack::MockRequest.new(app).put("", :input => "foo")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "PUT"

    res = Rack::MockRequest.new(app).patch("", :input => "foo")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "PATCH"

    res = Rack::MockRequest.new(app).delete("", :input => "foo")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "DELETE"

    Rack::MockRequest.env_for("/", :method => "HEAD")["REQUEST_METHOD"]
     .must_equal "HEAD"

    Rack::MockRequest.env_for("/", :method => "OPTIONS")["REQUEST_METHOD"]
     .must_equal "OPTIONS"
  end

  it "set content length" do
    env = Rack::MockRequest.env_for("/", :input => "foo")
    env["CONTENT_LENGTH"].must_equal "3"

    env = Rack::MockRequest.env_for("/", :input => StringIO.new("foo"))
    env["CONTENT_LENGTH"].must_equal "3"

    env = Rack::MockRequest.env_for("/", :input => Tempfile.new("name").tap { |t| t << "foo" })
    env["CONTENT_LENGTH"].must_equal "3"

    env = Rack::MockRequest.env_for("/", :input => IO.pipe.first)
    env["CONTENT_LENGTH"].must_be_nil
  end

  it "allow posting" do
    res = Rack::MockRequest.new(app).get("", :input => "foo")
    env = unmarshal(res.body)
    env["mock.postdata"].must_equal "foo"

    res = Rack::MockRequest.new(app).post("", :input => StringIO.new("foo"))
    env = unmarshal(res.body)
    env["mock.postdata"].must_equal "foo"
  end

  it "use all parts of an URL" do
    res = Rack::MockRequest.new(app).
      get("https://bla.example.org:9292/meh/foo?bar")
    res.must_be_kind_of Rack::MockResponse

    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "bla.example.org"
    env["SERVER_PORT"].must_equal "9292"
    env["QUERY_STRING"].must_equal "bar"
    env["PATH_INFO"].must_equal "/meh/foo"
    env["rack.url_scheme"].must_equal "https"
  end

  it "set SSL port and HTTP flag on when using https" do
    res = Rack::MockRequest.new(app).
      get("https://example.org/foo")
    res.must_be_kind_of Rack::MockResponse

    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "example.org"
    env["SERVER_PORT"].must_equal "443"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["rack.url_scheme"].must_equal "https"
    env["HTTPS"].must_equal "on"
  end

  it "prepend slash to uri path" do
    res = Rack::MockRequest.new(app).
      get("foo")
    res.must_be_kind_of Rack::MockResponse

    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["SERVER_NAME"].must_equal "example.org"
    env["SERVER_PORT"].must_equal "80"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["rack.url_scheme"].must_equal "http"
  end

  it "properly convert method name to an uppercase string" do
    res = Rack::MockRequest.new(app).request(:get)
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
  end

  it "accept params and build query string for GET requests" do
    res = Rack::MockRequest.new(app).get("/foo?baz=2", :params => {:foo => {:bar => "1"}})
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["QUERY_STRING"].must_include "baz=2"
    env["QUERY_STRING"].must_include "foo[bar]=1"
    env["PATH_INFO"].must_equal "/foo"
    env["mock.postdata"].must_equal ""
  end

  it "accept raw input in params for GET requests" do
    res = Rack::MockRequest.new(app).get("/foo?baz=2", :params => "foo[bar]=1")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "GET"
    env["QUERY_STRING"].must_include "baz=2"
    env["QUERY_STRING"].must_include "foo[bar]=1"
    env["PATH_INFO"].must_equal "/foo"
    env["mock.postdata"].must_equal ""
  end

  it "accept params and build url encoded params for POST requests" do
    res = Rack::MockRequest.new(app).post("/foo", :params => {:foo => {:bar => "1"}})
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "POST"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["CONTENT_TYPE"].must_equal "application/x-www-form-urlencoded"
    env["mock.postdata"].must_equal "foo[bar]=1"
  end

  it "accept raw input in params for POST requests" do
    res = Rack::MockRequest.new(app).post("/foo", :params => "foo[bar]=1")
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "POST"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["CONTENT_TYPE"].must_equal "application/x-www-form-urlencoded"
    env["mock.postdata"].must_equal "foo[bar]=1"
  end

  it "accept params and build multipart encoded params for POST requests" do
    files = Rack::Multipart::UploadedFile.new(File.join(File.dirname(__FILE__), "multipart", "file1.txt"))
    res = Rack::MockRequest.new(app).post("/foo", :params => { "submit-name" => "Larry", "files" => files })
    env = unmarshal(res.body)
    env["REQUEST_METHOD"].must_equal "POST"
    env["QUERY_STRING"].must_equal ""
    env["PATH_INFO"].must_equal "/foo"
    env["CONTENT_TYPE"].must_equal "multipart/form-data; boundary=AaB03x"
    # The gsub accounts for differences in YAMLs affect on the data.
    env["mock.postdata"].gsub("\r", "").length.must_equal 206
  end

  it "behave valid according to the Rack spec" do
    url = "https://bla.example.org:9292/meh/foo?bar"
    Rack::MockRequest.new(app).get(url, :lint => true).
      must_be_kind_of Rack::MockResponse
  end

  it "call close on the original body object" do
    called = false
    body   = Rack::BodyProxy.new(['hi']) { called = true }
    capp   = proc { |e| [200, {'Content-Type' => 'text/plain'}, body] }
    called.must_equal false
    Rack::MockRequest.new(capp).get('/', :lint => true)
    called.must_equal true
  end
end

describe Rack::MockResponse do
  it "provide access to the HTTP status" do
    res = Rack::MockRequest.new(app).get("")
    res.must_be :successful?
    res.must_be :ok?

    res = Rack::MockRequest.new(app).get("/?status=404")
    res.wont_be :successful?
    res.must_be :client_error?
    res.must_be :not_found?

    res = Rack::MockRequest.new(app).get("/?status=501")
    res.wont_be :successful?
    res.must_be :server_error?

    res = Rack::MockRequest.new(app).get("/?status=307")
    res.must_be :redirect?

    res = Rack::MockRequest.new(app).get("/?status=201", :lint => true)
    res.must_be :empty?
  end

  it "provide access to the HTTP headers" do
    res = Rack::MockRequest.new(app).get("")
    res.must_include "Content-Type"
    res.headers["Content-Type"].must_equal "text/yaml"
    res.original_headers["Content-Type"].must_equal "text/yaml"
    res["Content-Type"].must_equal "text/yaml"
    res.content_type.must_equal "text/yaml"
    res.content_length.wont_equal 0
    res.location.must_be_nil
  end

  it "provide access to the HTTP body" do
    res = Rack::MockRequest.new(app).get("")
    res.body.must_match(/rack/)
    assert_match(res, /rack/)
  end

  it "provide access to the Rack errors" do
    res = Rack::MockRequest.new(app).get("/?error=foo", :lint => true)
    res.must_be :ok?
    res.errors.wont_be :empty?
    res.errors.must_include "foo"
  end

  it "allow calling body.close afterwards" do
    # this is exactly what rack-test does
    body = StringIO.new("hi")
    res = Rack::MockResponse.new(200, {}, body)
    body.close if body.respond_to?(:close)
    res.body.must_equal 'hi'
  end

  it "optionally make Rack errors fatal" do
    lambda {
      Rack::MockRequest.new(app).get("/?error=foo", :fatal => true)
    }.must_raise Rack::MockRequest::FatalWarning
  end
end

describe Rack::MockResponse, 'headers' do
  before do
    @res = Rack::MockRequest.new(app).get('')
    @res.set_header 'FOO', '1'
  end

  it 'has_header?' do
    lambda { @res.has_header? nil }.must_raise NoMethodError

    @res.has_header?('FOO').must_equal true
    @res.has_header?('Foo').must_equal true
  end

  it 'get_header' do
    lambda { @res.get_header nil }.must_raise NoMethodError

    @res.get_header('FOO').must_equal '1'
    @res.get_header('Foo').must_equal '1'
  end

  it 'set_header' do
    lambda { @res.set_header nil, '1' }.must_raise NoMethodError

    @res.set_header('FOO', '2').must_equal '2'
    @res.get_header('FOO').must_equal '2'

    @res.set_header('Foo', '3').must_equal '3'
    @res.get_header('Foo').must_equal '3'
    @res.get_header('FOO').must_equal '3'

    @res.set_header('FOO', nil).must_be_nil
    @res.get_header('FOO').must_be_nil
    @res.has_header?('FOO').must_equal true
  end

  it 'add_header' do
    lambda { @res.add_header nil, '1' }.must_raise NoMethodError

    # Sets header on first addition
    @res.add_header('FOO', '1').must_equal '1,1'
    @res.get_header('FOO').must_equal '1,1'

    # Ignores nil additions
    @res.add_header('FOO', nil).must_equal '1,1'
    @res.get_header('FOO').must_equal '1,1'

    # Converts additions to strings
    @res.add_header('FOO', 2).must_equal '1,1,2'
    @res.get_header('FOO').must_equal '1,1,2'

    # Respects underlying case-sensitivity
    @res.add_header('Foo', 'yep').must_equal '1,1,2,yep'
    @res.get_header('Foo').must_equal '1,1,2,yep'
    @res.get_header('FOO').must_equal '1,1,2,yep'
  end

  it 'delete_header' do
    lambda { @res.delete_header nil }.must_raise NoMethodError

    @res.delete_header('FOO').must_equal '1'
    @res.has_header?('FOO').must_equal false

    @res.has_header?('Foo').must_equal false
    @res.delete_header('Foo').must_be_nil
  end
end

MTest::Unit.new.run
