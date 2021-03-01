module MeltingPot
    class RouteRepository
      NAMESPACE = "routes".freeze
      DELIM = "\\".freeze
  
      def initialize( redis, conv = RouteConverter.new, logger = Logger.new( STDERR ) )
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
        RouteProxy.new( @redis.hmget( "#{ NAMESPACE }#{ DELIM }#{ id }", "source", "destination", "scheme", "auth_required" ), @conv )
      end
  
      alias update create
  
      def delete( id )
        @redis.del( "#{ NAMESPACE }#{ DELIM }#{ id }" )
      end
    end
  
    class RouteConverter
      def initialize
        super
      end
  
      def encode( entity )
        [
          "source"          ,
          entity.source     ,
          "destination"     ,  
          entity.destination,  
          "scheme"          ,
          entity.scheme     ,
          "auth_required"   ,
          entity.auth_required.to_s
        ]
      end
  
      def decode( data )
        Route.new(
          :source        => data[0],
          :destination   => data[1],
          :scheme        => data[2],
          :auth_required => data[3].to_b
        )
      end
    end
  
    class RouteProxy
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