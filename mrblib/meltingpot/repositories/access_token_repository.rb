module MeltingPot
  class AccessTokenRepository
    NAMESPACE = "acess_token".freeze
    DELIM = "\\".freeze

    def initialize( redis, conv = BearerTokenConverter.new, logger = Logger.new( STDERR ) )
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
      AccessTokenProxy.new( @redis.hmget( "#{ NAMESPACE }#{ DELIM }#{ id }", "access_token", "token_type", "expires", "user_id" ), @conv )
    end

    alias update create

    def delete( id )
      @redis.del( "#{ NAMESPACE }#{ DELIM }#{ id }" )
    end

    def expire( id, expiry )
      @redis.expire( "#{ NAMESPACE }#{ DELIM }#{ id }", expiry )
    end
  end

  class BearerTokenConverter
    def initialize
      super
    end

    def encode( entity )
      [
        "access_token"                   ,
        entity.access_token              ,
        "token_type"                     ,  
        entity.token_type                ,
        "expires"                        ,
        String( Float( entity.expires ) ),
        "user_id"                        ,
        entity.user_id
      ]
    end

    def decode( data )
      BearerToken.new(
        :access_token => data[0]                    ,
        :token_type   => data[1]                    ,
        :expires      => Time.at( Float( data[2] ) ),
        :user_id      => data[3]
      )
    end
  end

  class AccessTokenProxy
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