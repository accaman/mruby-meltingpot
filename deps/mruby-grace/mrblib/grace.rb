class Grace
  class GraceError < StandardError; end
  class NotFound   < GraceError   ; end

  REQUEST_METHODS = {
    "ANY" => R3::ANY,
    "GET" => R3::GET,
    "POST" => R3::POST,
    "PUT" => R3::PUT,
    "DELETE" => R3::DELETE,
    "PATCH" => R3::PATCH,
    "HEAD" => R3::HEAD,
    "OPTIONS" => R3::OPTIONS
  }

  class << self
    def routes
      @routes ||= []
    end

    REQUEST_METHODS.each do |k, v|
      eval <<EOT
def #{k.downcase}(path, &handler) routes << [path, #{v}, handler]; end
EOT
    end
  end

  def initialize(app = nil)
    @app  = app
    @tree = R3::Tree.new(self.class.routes.size)
    self.class.routes.each { |route| @tree.add(*route) }
    @tree.compile
  end

  def call(env)
    dup.call!(env)
  end

  def call!(env)
    @env = env

    path = "#{env["SCRIPT_NAME"]}#{env["PATH_INFO"]}"
    request_method = REQUEST_METHODS[env["REQUEST_METHOD"]]
    if request_method
      node = @tree.match(path, request_method)
      if node
        params, handler = *node
        return instance_exec(*params.values, &handler)
      end
    end
    route_missing!
  end
  attr_reader :env

  private

    def route_missing!
      if @app
        return forward
      end
      raise NotFound, "#{@env["REQUEST_METHOD"]} #{@env["PATH_INFO"]}"
    end

    def forward
      if @app.respond_to?(:call)
        return @app.call(@env)
      end
      raise "object is not callable"
    end
end
