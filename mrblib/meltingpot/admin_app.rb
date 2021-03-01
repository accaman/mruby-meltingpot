module MeltingPot
  class DefaultNotFoundHandler
    def call(env)
      JsonResponse.new({ :message => "Page Not Found" }, 404).finish
    end
  end

  class AdminApp < Grace
    def initialize(app, opts = {})
      @logger = opts[:logger]
      @access_token_controller = opts[:access_token_controller]
      @user_controller = opts[:user_controller]
      @route_controller = opts[:route_controller]
      super(app)
    end
  
    def call(env)
      request_id = make_request_id(env["HTTP_X_REQUEST_ID"])
      env["HTTP_X_REQUEST_ID"] = request_id

      # XXX, RequestId is fiber local variable
      RequestId.set(request_id)

      super(env)
        .tap { |_status, headers, _body| headers["x-fallthru-set-X-REQUEST-ID"] = headers["X-Request-Id"] = RequestId.get }
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

    post "/users" do
      @user_controller.create(Rack::Request.new(env)).finish
    end

    get "/users/{username}" do |username|
      @user_controller.show(username, Rack::Request.new(env)).finish
    end

    delete "/users/{username}" do |username|
      @user_controller.destroy(username, Rack::Request.new(env)).finish
    end

    post "/token" do
      @access_token_controller.grant(Rack::Request.new(env)).finish
    end

    post "/routes" do
      @route_controller.create(Rack::Request.new(env)).finish
    end

    get "/routes/{source}" do |source|
      @route_controller.show(source, Rack::Request.new(env)).finish
    end

    delete "/routes/{source}" do |source|
      @route_controller.destroy(source, Rack::Request.new(env)).finish
    end

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

      redis_class = opts[:redis_class] || MeltingPot::DefaultRedis
      access_token_class = opts[:access_token_class] || MeltingPot::BearerToken
      access_token_converter_class = opts[:access_token_converter_class] || MeltingPot::BearerTokenConverter
      user_class = opts[:user_class] || MeltingPot::User
      user_converter_class = opts[:user_converter_class] || MeltingPot::UserConverter
      route_class = opts[:route_class] || MeltingPot::Route
      route_converter_class = opts[:route_converter_class] || MeltingPot::RouteConverter
      exceptions_app_class = opts[:exceptions_app_class] || MeltingPot::DefaultNotFoundHandler
      logger_class = opts[:logger_class] || MeltingPot::Logger
      log_formatter = opts[:log_formatter] || MeltingPot::LogFormatter

      redis = redis_class.new(redis_host, redis_port)
      access_token_converter = access_token_converter_class.new
      user_converter = user_converter_class.new
      route_converter = route_converter_class.new
      exceptions_app = exceptions_app_class.new 
      logger = logger_class.new(log_device, :formatter => log_formatter.new, :level => ::Logger.const_get(log_level))

      access_token_repository = AccessTokenRepository.new(redis, access_token_converter, logger)
      user_repository = UserRepository.new(redis, user_converter, logger)
      route_repository = RouteRepository.new(redis, route_converter, logger)

      access_token_interactor = AccessTokenInteractor.new(access_token_repository, user_repository, access_token_class, access_token_time_to_live, password_pepper, logger)
      user_interactor = UserInteractor.new(user_repository, user_class, password_pepper, logger)
      route_interactor = RouteInteractor.new(route_repository, route_class, logger)

      access_token_controller = AccessTokenController.new(access_token_interactor, logger)
      user_controller = UserController.new(user_interactor, logger)
      route_controller = RouteController.new(route_interactor, logger)

      new(exceptions_app, {
        :access_token_controller => access_token_controller,
        :user_controller => user_controller,
        :route_controller => route_controller,
        :logger => logger
      })
    end
  end
end