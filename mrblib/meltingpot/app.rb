module MeltingPot
  class MeltingPotError < StandardError; end

  class ClientError              < MeltingPotError; end # 400
  class BadRequestError          < ClientError; end # 400
  class UnauthorizedError        < ClientError; end # 401
  class ForbiddenError           < ClientError; end # 403
  class UnprocessableEntityError < ClientError; end # 422
  class NotFoundError            < ClientError; end # 404

  class ServerError         < MeltingPotError; end # 500
  class InternalServerError < ServerError; end # 500

  class Config< MiniDSL
    field :redis_host                , :type => String , :present => true
    field :redis_port                , :type => Integer, :present => true
    field :redis_password            , :type => String , :present => false
    field :redis_db                  , :type => Integer, :present => true
    field :redis_timeout             , :type => Integer, :present => true
    field :access_token_time_to_live , :type => Integer, :present => true
    field :log_device                , :type => String , :present => true
    field :log_level                 , :type => String , :present => true, :load => ->(v) { v.upcase }
    field :password_pepper           , :type => String , :present => true
    field :static_dir                , :type => String , :present => true
    field :session_domain            , :type => String 
    field :session_expire_after      , :type => Integer
    field :session_key               , :type => String 
    field :session_secure            # , :type => Boolean # false
  end

  class ConfigV1Conv
    def decode(spec)
      Config.new(
        :redis_host                => spec["redis_host"]                || "127.0.0.1"   ,
        :redis_port                => spec["redis_port"]                || 6379          ,
        :reids_password            => spec["redis_password"]            || nil           ,
        :redis_db                  => spec["redis_db"]                  || 0             ,
        :redis_timeout             => spec["redis_timeout"]             || 0             ,
        :access_token_time_to_live => spec["access_token_time_to_live"] || 60 * 60       ,
        :log_level                 => spec["error_log_level"]           || "DEBUG"       ,
        :log_device                => spec["log_device"]                || "/dev/stderr" ,
        :password_pepper           => spec["password_pepper"]           || ""            ,
        :static_dir                => spec["static_dir"]                || "/static"     ,
        :session_domain            => spec["session_domain"]            || nil           ,
        :session_expire_after      => spec["session_expire_after"]      || nil           ,
        :session_key               => spec["session_key"]               || "rack.session",
        :session_secure            => spec["session_secure"]            || false
      )
        .tap { |config| raise "validation failed: #{ config.errors }" if ! config.valid? }
    end
  end

  class ConfigParser
    class << self
      def setup!
        @version = {
          1 => ConfigV1Conv
        }
      end

      def parse_yml(yml)
        yml = YAML.load( File.open(yml, "r") { |handle| handle.read } )

        conv_class = @version[yml["version"] || 1]
        if conv_class.nil?
          raise "config version #{ yml["version"] } not supported"
        end

        new( conv_class.new() ).parse(yml["spec"])
      end
    end
    setup!

    def initialize(conv = ConfigV1Conv.new)
      @conv = conv
    end

    def parse(spec)
      @conv.decode(spec)
    end
  end

  class FiberLocal
    def set(v)
      local[Fiber.current.object_id] = v
    end

    def get
      local[Fiber.current.object_id]
    end

    private

      def local
        @local ||= {}
      end
  end
  RequestId = FiberLocal.new

  # TODO, fix
  class LogFormatter < ::Logger::Formatter
    FORMAT = "%s, [%s #%s] %5s -- %s: %s\n".freeze

    def call(sev, time, prog, msg)
      format \
        FORMAT, sev[0], format_datetime(time), request_id || 0, sev, prog, msg2str(msg)
    end

    private

      def request_id
        RequestId.get
      end
  end

  # Wrap around new to normalize with other initializers
  class Logger
    def self.new(dev, opts = {})
      ::Logger.new(dev, opts)
    end
  end

  class DefaultHttp
    def initialize
      super
    end

    def request(url, opts = {})
      http_request(url, opts)
    end
  end

  # TODO, move to admin app
  class JsonResponse
    DEFAULT_HEADERS = Rack::Utils::HeaderHash.new({
      "Content-Type" => "application/json; charset=utf-8"
    })

    def self.new(body = nil, status = 200, headers = {})
      if body.present?
        return Rack::Response.new(
          JSON.stringify(body),
          status,
          DEFAULT_HEADERS.merge(headers)
        )
      end
      Rack::Response.new([], status, headers)
    end
  end

  class DefaultRedis
    def self.new(host, port, opts = {})
      H2O::Redis.new(
        :host => host,
        :port => port,
        :db => opts[:db],
        :password => opts[:password],
        :connect_timeout => opts[:timeout],
        :command_timeout => opts[:timeout]
      )
    end
  end

  class DefaultServerErrorHandler
    def call(env)
      JsonResponse.new({ :message => "Internal Server Error" }, 500).finish
    end
  end

  class App
    def initialize(exceptions_app, opts = {})
      @logger = opts[:logger]
      @proxy_controller = opts[:proxy_controller]
      @app = exceptions_app
    end

    def call(env)
      dup.call!(env)
    end

    def call!(env)
      @env = env

      request_id = make_request_id(env["HTTP_X_REQUEST_ID"])
      env["HTTP_X_REQUEST_ID"] = request_id

      # XXX, RequestId is fiber local variable
      RequestId.set(request_id)

      @proxy_controller.proxy_pass(Rack::Request.new(env))
        .tap { |_status, headers, _body| headers["x-fallthru-set-X-REQUEST-ID"] = headers["X-REQUEST-ID"] = RequestId.get }
    rescue => err
      env["rack.logger"] = @logger
      env["rack.error"] = err

      server_error!
    end

    RestrictedCharactersPattern = /[^\w\-@]/

    # adapted from rails <github.com/rails/rails>
    # Copyright (c) 2007-2016 Nick Kallen, Bryan Helmkamp, Emilio Tagua, Aaron Patterson
    # Used under the MIT License:
    # https://opensource.org/licenses/mit-license.php
    def make_request_id(request_id)
      if request_id and request_id.size > 0
        request_id.gsub(RestrictedCharactersPattern, "").first(255)
      else
        internal_request_id
      end
    end

    def internal_request_id
      SecureRandom.uuid
    end

    def server_error!
      if @app
        return forward
      end
      raise ServerError, "#{ @env["REQUEST_METHOD"] } #{ @env["PATH_INFO"] }"
    end

    def forward
      if @app.respond_to?(:call)
        return @app.call(@env)
      end
      # RuntimeError
      raise "object is not callable"
    end

    # TODO, Refactoring
    def self.create(yml, opts = {})
      config = ConfigParser.parse_yml(yml)

      redis_host = config.redis_host           
      redis_port = config.redis_port           
      reids_password = config.redis_password           
      redis_db = config.redis_db           
      redis_timeout = config.redis_timeout           
      access_token_time_to_live = config.access_token_time_to_live           
      log_level = config.log_level           
      log_device = config.log_device
      password_pepper = config.password_pepper         
      static_dir = config.static_dir         
      session_domain = config.session_domain
      session_expire_after = config.session_expire_after
      session_key = config.session_key
      session_secure = config.session_secure

      http_class = opts[:http_class] || MeltingPot::DefaultHttp
      redis_class = opts[:redis_class] || MeltingPot::DefaultRedis
      access_token_class = opts[:access_token_class] || MeltingPot::BearerToken
      access_token_converter_class = opts[:access_token_converter_class] || MeltingPot::BearerTokenConverter
      user_class = opts[:user_class] || MeltingPot::User
      user_converter_class = opts[:user_converter_class] || MeltingPot::UserConverter
      route_class = opts[:route_class] || MeltingPot::Route
      route_converter_class = opts[:route_converter_class] || MeltingPot::RouteConverter
      exceptions_app_class = opts[:exceptions_app_class] || MeltingPot::DefaultServerErrorHandler
      logger_class = opts[:logger_class] || MeltingPot::Logger
      log_formatter = opts[:log_formatter] || MeltingPot::LogFormatter
      secure_random_class = opts[:secure_random_class] || ::SecureRandom

      http = http_class.new
      redis = redis_class.new(redis_host, redis_port)
      access_token_converter = access_token_converter_class.new
      user_converter = user_converter_class.new
      route_converter = route_converter_class.new
      exceptions_app = exceptions_app_class.new 
      logger = logger_class.new(log_device, :formatter => log_formatter.new, :level => ::Logger.const_get(log_level))

      access_token_repository = AccessTokenRepository.new(redis, access_token_converter, logger)
      user_repository = UserRepository.new(redis, user_converter, logger)
      route_repository = RouteRepository.new(redis, route_converter, logger)

      rest_api_proxy_interactor = RestApiProxyInteractor.new(access_token_repository, route_repository, http, logger)
      any_proxy_interactor = AnyProxyInteractor.new(user_repository, route_repository, http, logger)
      proxy_controller = ProxyController.new(rest_api_proxy_interactor, any_proxy_interactor, static_dir, logger)

      app = new(exceptions_app, {
        :proxy_controller => proxy_controller,
        :logger => logger
      })
      Rack::Session::Redis.new(app, {
        :cache => redis,
        :domain => session_domain,
        :expire_after => session_expire_after,
        :key => session_key,
        :secure => session_secure,
        :secure_random => secure_random_class
      })
    end
  end
end
