module MeltingPot
  class MeltingPotError < StandardError; end

  class ProxyController
    def initialize( rest_api_proxy_interactor, any_proxy_interactor, static_dir = "/app/static", logger = Logger.new(STDERR) )
      @rest_api_proxy_interactor = rest_api_proxy_interactor
      @any_proxy_interactor = any_proxy_interactor
      @static_dir = static_dir
      @logger = logger
    end
    attr_reader :rest_api_proxy_interactor, :any_proxy_interactor, :static_dir, :logger

    def proxy_pass(req)
      ProxyPassAdapter[proxy_pass_type(req)].new(self).proxy_pass(req)
    end

    def proxy_pass_type(req)
      req.get_header("HTTP_CONTENT_TYPE").try { |content_type| content_type.downcase.include?("application/json") } \
        || req.get_header("HTTP_AUTHORIZATION").try { |auth| auth = auth.downcase; auth.include?("bearer") || auth.include?("mac") } ? :rest_api : :any
    end

    class UnsupportedProxyPassTypeError < MeltingPotError  ; end

    class ProxyPassAdapter
      class << self
        def register(k, v)
          adapters[k] = v
        end

        def [](k)
          adapter = adapters[k]
          if ! adapter
            raise UnsupportedProxyPassTypeError, "unsupported proxy pass type: #{ k }"
          end
          adapter
        end

        def adapters
          @adapters ||= {}
        end
      end

      def initialize(proxy_controller)
        @proxy_controller = proxy_controller
      end

      def proxy_pass(req)
        raise NotImplementedError
      end

      def make_headers(req)
        # see RFC 3875 - The Common Gateway Interface(CGI) <https://tools.ietf.org/html/rfc3876> 
        header_hash = Rack::Utils::HeaderHash[req.env.select { |k, _| k[0, 5] == "HTTP_" }
            .map { |k, v| [k[5, k.length].gsub("_", "-"), v] }]
        if header_hash["X-FORWARDED-FOR"]
          header_hash["X-FORWARDED-FOR"] << ", #{ req.get_header('REMOTE_ADDR') || '127.0.0.1' }"
        else
          header_hash["X-FORWARDED-FOR"] = req.get_header("REMOTE_ADDR") || "127.0.0.1"
        end
        len = req.content_length
        if len
          header_hash["CONTENT-LENGTH"] = len
        end
        type = req.content_type
        if type
          header_hash["CONTENT-TYPE"] = type
        end
        # XXX, sanitizing headers for passing them to the upstream
        header_hash.delete( "AUTHORIZATION" )
        header_hash.delete( "X-USER-ID" )
        header_hash.delete( "X-USER-ROLE" )
        # Host header will be added by interactor
        header_hash.delete( "HOST" )
        header_hash
      end
    end
    
    # this is input boundary
    class RestApiContext
      BEARER_PATTERN = /(Bearer)\s+([\w\d\-._~+\/]+)/i

      def self.from_request(req)
        if req.has_header?("HTTP_AUTHORIZATION")
          _, token_type, access_token = *( req.get_header("HTTP_AUTHORIZATION").match(BEARER_PATTERN) )
          new(token_type, access_token)
        else
          new(nil, nil)
        end
      end

      def initialize(token_type, access_token)
        @token_type = token_type
        @access_token = access_token
      end
      attr_reader :token_type, :access_token
    end

    class RestApi < ProxyPassAdapter
      def proxy_pass(req)
        ctx = RestApiContext.from_request(req)
        rs = @proxy_controller.rest_api_proxy_interactor.proxy_pass(ctx, req.url, req.request_method, make_headers(req), req.body)
        [rs.status, rs.headers, rs.body]
      rescue UnauthorizedError => err
        @proxy_controller.logger.error(err)
        [
          401,
          { 
            "Content-Type" => "application/json; charset=utf-8",
            "Cache-Control" => "no-store",
            "Pragma" => "no-cache"
          },
          [
            JSON.stringify({ :message => "Unauthorized" })
          ]
        ]
      rescue NotFoundError => err
        @proxy_controller.logger.error(err)
        [
          404,
          { 
            "Content-Type" => "application/json; charset=utf-8",
          },
          [
            JSON.stringify({ :message => "Not Found" })
          ]
        ]
      rescue => err
        @proxy_controller.logger.error(err)
        [
          500,
          { 
            "Content-Type" => "application/json; charset=utf-8",
          },
          [
            JSON.stringify({ :message => "Internal Server Error" })
          ]
        ]
      end
    end
    ProxyPassAdapter.register :rest_api, RestApi

    class AnyContext
      def self.from_request(req)
        if req.session.key?("user_id")
          new(req.session["user_id"], nil, true)
        elsif req.post?
          new(req.params["username"], req.params["password"], false)
        else
          new(nil, nil, false)
        end
      end

      def initialize(username, password, session_started)
        @username = username
        @password = password
        @session_started = session_started
      end
      attr_reader :username, :password, :session_started

      def session_started?
        @session_started
      end
    end

    class Any < ProxyPassAdapter
      def proxy_pass( req )
        ctx = AnyContext.from_request( req )
        rs = @proxy_controller.any_proxy_interactor.proxy_pass(ctx, req.url, req.request_method, make_headers(req), req.body)
        # update session if user verified
        p req.session["user_id"] = rs.verified_user_id if rs.verified_user_id.present?
        # TODO, Wrap around with Response
        [rs.status, rs.headers, rs.body]
      rescue BadRequestError => err
        @proxy_controller.logger.error(err)
        [
          400,
          {
            "Cache-Control" => "no-store",
            "Pragma" => "no-cache",
            "x-reproxy-url" => File.join(@proxy_controller.static_dir, "/html/400.html")
          },
          []
        ]
      rescue UnauthorizedError => err
        @proxy_controller.logger.error(err)
        [
          401,
          {
            "Cache-Control" => "no-store",
            "Pragma" => "no-cache",
            "x-reproxy-url" => File.join(@proxy_controller.static_dir, "/html/401.html")
          },
          []
        ]
      rescue NotFoundError => err
        @proxy_controller.logger.error(err)
        [404, { "x-reproxy-url" => File.join(@proxy_controller.static_dir, "/html/404.html") }, []]
      rescue => err
        @proxy_controller.logger.error(err)
        [500, { "x-reproxy-url" => File.join(@proxy_controller.static_dir, "/html/500.html") }, []]
      end
    end
    ProxyPassAdapter.register :any, Any
  end
end