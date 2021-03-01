module MeltingPot
  class AccessTokenInteractor
    def initialize( access_token_repository, user_repository, access_token_class = BearerToken, time_to_live = 60 * 60, pepper = "", logger = Logger.new(STDERR) )
      @access_token_repository = access_token_repository
      @user_repository = user_repository
      @access_token_class = access_token_class
      @time_to_live = time_to_live
      @pepper = pepper
      @logger = logger
    end
    attr_reader :time_to_live

    def acquire(username, password)
      if ! @user_repository.find(username).join.try { |user| user.confirm_password("#{ password }#{ @pepper }") }
        return
      end
      @access_token_class.create(@time_to_live, username).tap { |token|
        @access_token_repository.create(token).join
        @access_token_repository.expire(token.access_token, @time_to_live).join
      }
    end

    def dispose(access_token)
      @access_token_repository.delete(access_token).join
    end
  end
end