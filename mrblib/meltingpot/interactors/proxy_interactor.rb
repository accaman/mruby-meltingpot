module MeltingPot
  class ProxyInteractor
    # @see https://developer.mozilla.org/ar/docs/Mozilla/Add-ons/WebExtensions/Match_patterns
    URL_PATTERN = /(\*|http|https):\/\/(\*|(?:\*\.)?(?:[^\/*]+))?(.*)/

    def proxy_pass(_, url, request_method = "GET", headers = {}, body = [])
      future = @http.request(url, :method => request_method, :headers => headers, :body => body)
      starting_time = Time.now
      # TODO, Check `client-warning` Header
      Result.new( *future.join() )
        .tap { |rs| rs.headers["x-fallthru-set-RTT"] = (Time.now - starting_time).floor(3) }
    end

    # this is output boundary
    class Result
      def initialize(status = 200, headers = {}, body = [], verified_user_id = nil)
        @status = status
        @headers = headers
        @body = body
        @verified_user_id = verified_user_id
      end
      attr_accessor :status, :headers, :body, :verified_user_id
    end
  end

  class RestApiProxyInteractor < ProxyInteractor
    def initialize( access_token_repository, route_repository, http, logger = Logger.new(STDERR) )
      @access_token_repository = access_token_repository
      @route_repository = route_repository
      @http = http
      @logger = logger
    end

    def proxy_pass(ctx, url, request_method = "GET", headers = {}, body = [])
      # speculative execution for finding access token
      future_token = ctx.access_token.present? \
        ? @access_token_repository.find(ctx.access_token) : nil 

      # translate url
      _, scheme, host, path = *url.match(URL_PATTERN)
      route = @route_repository.find(host).join
      if route.nil?
        _ = future_token.try(:join)
        raise NotFoundError, "not found: #{ url }"
      end
      destination_url = [(route.scheme || scheme), "://", route.destination, path].join

      # add headers
      headers["X-FORWARDED-PROTO"] ||= scheme
      headers["X-FORWARDED-HOST"]  ||= host
      headers["HOST"] = route.destination

      # attempt to authenticate
      verified_user_id = nil
      token = future_token.try(:join)
      if route.auth_required
        if token.nil?
          raise UnauthorizedError, "access token not exists: #{ ctx.access_token }"
        end
        if !token.verify
          raise UnauthorizedError, "access token not valid: #{ ctx.access_token }"
        end
        headers["X-USER-ID"] = token.user_id
        verified_user_id = token.user_id
      end

      # pass request to upstream
      super(ctx, destination_url, request_method , headers, body)
        .tap { |rs| 
          if verified_user_id.present?
            rs.verified_user_id = verified_user_id
            rs.headers["x-fallthru-set-X-USER-ID"] = verified_user_id
          end
        }
    end
  end

  class AnyProxyInteractor < ProxyInteractor
    def initialize( user_repository, route_repository, http, logger = Logger.new(STDERR) )
      @user_repository = user_repository
      @route_repository = route_repository
      @http = http
      @logger = logger
    end

    def proxy_pass(ctx, url, request_method = "GET", headers = {}, body = [])
      # speculative execution for finding access token
      future_user = ctx.username.present? \
        ? @user_repository.find(ctx.username) : nil

      # translate url
      _, scheme, host, path = *url.match(URL_PATTERN)
      route = @route_repository.find(host).join
      if route.nil?
        _ = future_user.try(:join)
        raise NotFoundError, "not found: #{ url }"
      end
      destination_url = [(route.scheme || scheme), "://", route.destination, path].join

      # add headers
      headers["X-FORWARDED-PROTO"] ||= scheme
      headers["X-FORWARDED-HOST"]  ||= host
      headers["HOST"] = route.destination

      # attempt to authenticate
      verified_user_id = nil 
      user = future_user.try(:join)
      if route.auth_required
        if ctx.session_started?
          if user.nil?
            raise UnauthorizedError, "user not exists: #{ username }"
          end
        else
          ctx_errors = []
          ctx_errors << "username must be present" if ctx.username.blank?
          ctx_errors << "password must be present" if ctx.password.blank?
          if ctx_errors.size > 0
            raise BadRequestError, "validation failed: #{ ctx_errors }"
          end

          if !user
            raise UnauthorizedError, "user not exists: #{ ctx.username }"
          end
          if !user.confirm_password(ctx.password)
            raise UnauthorizedError, "user not valid: #{ ctx.username }"
          end
          # throw away password credentials
          request_method = "GET"
          body = []
        end
        headers["X-USER-ID"] = user.id
        verified_user_id = user.id
      end

      # pass request to upstream
      super(ctx, destination_url, request_method, headers, body)
        .tap { |rs| 
          if verified_user_id.present?
            rs.verified_user_id = verified_user_id
            rs.headers["x-fallthru-set-X-USER-ID"] = verified_user_id
          end
        }
    end
  end
end