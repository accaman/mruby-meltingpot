module MeltingPot
  class UserInteractor
    SALT_SIZE = 256 / 8

    def initialize( user_repository, user_class = User, pepper = "", logger = Logger.new(STDERR) )
      @user_repository = user_repository
      @user_class = user_class
      @pepper = pepper    
      @logger = logger    
    end
    attr_reader :pepper

    def create(username, password)
      @user_class.create(username, "#{ password }#{ @pepper }")
        .tap { |user| @user_repository.create(user).join }
    end

    def find_all
      raise NotImplementedError
    end

    def find(id)
      @user_repository.find(id).join
    end

    def update(id, fields = {})
      raise NotImplementedError
    end

    def delete(id)
      @user_repository.delete(id).join
    end
  end
end