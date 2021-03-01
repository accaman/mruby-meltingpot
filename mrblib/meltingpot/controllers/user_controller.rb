module MeltingPot
  class UserController
    # REF: https://help.twitter.com/en/managing-your-account/change-twitter-handle
    USERNAME_POLICY = /\A[a-z\d]{5,15}+\z/i

    # REF: https://help.twitter.com/en/safety-and-security/account-security-tips
    PASSWORD_POLICY = /\A(?=.*?[a-z])(?=.*?\d)(?=.*?[!-\/:-@\[-`{-~])[!-~]{10,127}+\z/i

    def initialize( user_interactor, logger = Logger.new(STDERR) )
      @user_interactor = user_interactor
      @logger = logger
    end

    def index
      raise NotImplementedError
    end

    def show(username, _req = nil)
      user = @user_interactor.find(username)
      if user.nil?
        return JsonResponse.new({ :message => "Not Found" }, 404)
      end
      JsonResponse.new({ :username => user.username })
    end

    # TODO, Refactoring
    def create(req)
      errors = []

      username = req.params["username"]
      if username.blank?
        errors << "missing parameter (username)" 
      elsif USERNAME_POLICY.match(username).nil?
        errors << "invalid parameter (username): username does not match the policy"
      elsif @user_interactor.find(username)
        errors << "a user already exists: #{ username }"
      end

      password = req.params["password"]
      if password.blank?
        errors << "missing parameter (password)" 
      elsif PASSWORD_POLICY.match(password).nil?
        errors << "invalid parameter (password): password does not match the policy"
      end

      if errors.present?
        return JsonResponse.new({ :message => "Validation Failed", :errors  => errors }, 422)
      end
      user = @user_interactor.create(username, password)

      JsonResponse.new({ :username => user.username }, 201)
    end

    def update(username, _req = nil)
      raise NotImplementedError
    end

    def destroy(username, _req = nil)
      if @user_interactor.delete(username)
        JsonResponse.new(nil, 204)
      else
        JsonResponse.new({ :message => "Not Found" }, 404)
      end
    end
  end
end