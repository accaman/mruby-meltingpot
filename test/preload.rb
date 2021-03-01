module MeltingPot
  class TestHTTP
    def initialize
      super
    end

    def request(url, opts = {})
      case 
      when url.include?("/401")
        TestFuture.new([
          401,
          {} ,
          TestFuture.new(StringIO.new( 'Unauthorized' ))
        ])
      when url.include?("/403")
        TestFuture.new([
          403,
          {} ,
          TestFuture.new(StringIO.new( "Forbidden" ))
        ])
      when url.include?("/echo")
        TestFuture.new([
          200                 ,
          opts[:headers] || {},
          TestFuture.new( opts[:body] || StringIO.new("OK") )
        ])
      else
        TestFuture.new([
          200,
          {} ,
          TestFuture.new( StringIO.new("OK") )
        ])
      end
    end
  end

  class TestRedis
    def initialize(host, port, _ = {})
      @redis = ::Redis.new(host, port)
    end

    [:expire, :get, :set, :del, :hmget, :hmset, :ping].each do |m|
      eval <<EOT
def #{ m }( *argv )
  TestFuture.new( @redis.send("#{ m }", *argv) )
end
EOT
    end

    # DefaultRedis#exists returns integer
    def exists(k)
      TestFuture.new( @redis.exists?(k) ? 1 : 0 )
    end
  end

  class TestFuture
    def initialize(result)
      @result = result
    end

    def join
      return @result
    end
  end
end