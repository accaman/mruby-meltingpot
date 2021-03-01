module MeltingPot
  class UserRepository
    NAMESPACE = "users".freeze
    DELIM = "\\".freeze

    def initialize( redis, conv = UserConverter.new, logger = Logger.new( STDERR ) )
      @redis  = redis
      @conv   = conv
      @logger = logger
    end

    def create( entity )
      @redis.hmset( "#{ NAMESPACE }#{ DELIM }#{ entity.id }", *@conv.encode( entity ) )
    end

    def find_all
      raise NotImplementedError
    end

    def find( id )
      # XXX, order is important
      UserProxy.new( @redis.hmget( "#{ NAMESPACE }#{ DELIM }#{ id }", "username", "encrypted_password", "salt" ), @conv )
    end

    alias update create

    def delete( id )
      @redis.del( "#{ NAMESPACE }#{ DELIM }#{ id }" )
    end
  end

  class UserConverter
    def initialize
      super
    end

    def encode( entity )
      [
        "username"               ,
        entity.username          ,
        "encrypted_password"     ,  
        entity.encrypted_password,  
        "salt"                   ,
        entity.salt              ,
      ]
    end

    def decode( data )
      User.new(
        :username           => data[0],
        :encrypted_password => data[1],
        :salt               => data[2]
      )
    end
  end

  class UserProxy
    def initialize( promise, conv )
      @promise = promise
      @conv    = conv
    end

    def join
      data = @promise.join
      if ! data.any?
        return nil
      end
      @conv.decode( data )
    end
  end
end