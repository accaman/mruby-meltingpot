module MeltingPot
  class MeltingPotError < StandardError; end

  class AccessTokenController
    def initialize( access_token_interactor, logger = Logger.new(STDERR) )
      @access_token_interactor = access_token_interactor
      @logger = logger
    end
    attr_reader :access_token_interactor, :logger

    def grant(req)
      GrantAdapter[grant_type(req)].new(self).grant(req)
    rescue UnsupportedGrantTypeError => e
      JsonResponse.new(
        {
          "error" => "invalid_client",
          "error_description" => e.message
        },
        400,
        {
          "Cache-Control" => "no-store",
          "Pragma" => "no-cache"
        }
      )
    end

    def grant_type(req)
      req.params["grant_type"].try { |grant_type| grant_type.downcase.to_sym }
    end

    class UnsupportedGrantTypeError < MeltingPotError  ; end

    class GrantAdapter
      class << self
        def register(k, v)
          adapters[k] = v
        end

        def [](k)
          adapter = adapters[k]
          if ! adapter
            raise UnsupportedGrantTypeError, "unsupported grant type: #{ k }"
          end
          adapter
        end

        def adapters
          @adapters ||= {}
        end
      end

      def initialize(access_token_controller)
        @access_token_controller = access_token_controller
      end

      def grant(req)
        raise NotImplementedError
      end
    end

    class PasswordCredentials < GrantAdapter
      def grant(req)
        errors = []
        username = req.params["username"]
        if username.blank?
          errors << "missing parameter (username)" 
        end
        password = req.params["password"]
        if password.blank?
          errors << "missing parameter (password)" 
        end
        if errors.present?
          return JsonResponse.new(
            {
              "error" => "invalid_request",
              "error_description" => "Validation Failed: [#{ errors.join(', ') }]"
            },
            400,
            {
              "Cache-Control" => "no-store",
              "Pragma" => "no-cache"
            }
          )
        end

        token = @access_token_controller.access_token_interactor.acquire(username, password)
        if token.blank?
          return JsonResponse.new(
            {
              "error" => "invalid_client",
              "error_description" => "Authorization Failed"
            },
            400,
            {
              "Cache-Control" => "no-store",
              "Pragma" => "no-cache"
            }
          )
        end

        JsonResponse.new(
          {
            "access_token" => token.access_token,
            "token_type"   => token.token_type  ,
            "expires_in"   => @access_token_controller.access_token_interactor.time_to_live
          },
          200,
          {
            "Cache-Control" => "no-store",
            "Pragma" => "no-cache"
          }
        )  
      end
    end
    GrantAdapter.register :password, PasswordCredentials

    # TODO, impl
    def revoke(req)
      raise NotImplementedError
    end
  end
end
