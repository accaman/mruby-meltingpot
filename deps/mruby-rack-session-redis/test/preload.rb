module Rack
  module Session
    class Redis < Abstract::ID
      class TestRedis
        def initialize(host, port, _ = {})
          @redis = ::Redis.new( host, port )
        end

        [:expire, :get, :set, :del, :ping].each do |m|
          eval <<EOT
def #{ m }( *argv )
  result = @redis.send("#{ m }", *argv)
  TestFuture.new( result )
end
EOT
        end

        # DefaultRedis#exists returns integer
        def exists(k)
          result = @redis.exists?(k) ? 1 : 0
          TestFuture.new(result)
        end
      end

      class TestFuture
        def initialize(result)
          @result = result
        end

        def join
          @result
        end
      end
    end
  end
end
