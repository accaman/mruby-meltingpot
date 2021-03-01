module Rack
  module Session
    class Redis < Abstract::ID
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge(
        {
          :namespace => 'rack:session',
          :host => '127.0.0.1',
          :port => 6379,
          :db => nil,
          :password => nil,
          :connect_timeout => 1,
          :command_timeout => 1,
        }
      ).freeze

      # Wrap around H2O::Redis.new to normalize with orther Redis initializers
      class DefaultRedis
        def self.new(host, port, opts = {})
          H2O::Redis.new(
            {
              :host => host,
              :port => port,
              :db => opts[:db],
              :password => opts[:password],
              :connect_timeout => opts[:connect_timeout],
              :command_timeout => opts[:command_timeout]
            }
          )
        end
      end

      def initialize(app, options = {})
        super

        redis_host = @default_options[:host]
        redis_port = @default_options[:port]
        redis_opts = @default_options.reject { |k, v| ! Redis::DEFAULT_OPTIONS.include? k }

        @redis = options[:cache] || DefaultRedis.new(redis_host, redis_port, redis_opts)
        unless @redis.ping.join == "PONG"
          raise "No redis server"
        end
      end
      attr_reader :redis

      def generate_sid
        loop do
          sid = super
          break sid unless @redis.exists(sid).join > 0
        end
      end

      def get_session(env, sid)
        unless sid and session = @redis.get(sid).join
          sid, session = generate_sid, "{}"
          @redis.set(sid, session).join
        end
        [sid, JSON.parse(session)]
      end

      def set_session(env, session_id, new_session, options)
        expiry = options[:expire_after]
        expiry = expiry.nil? ? 0 : expiry + 1

        @redis.set(session_id, JSON.stringify(new_session)).join
        @redis.expire(session_id, expiry).join

        session_id
      end

      def destroy_session(env, session_id, options)
        @redis.del(session_id).join
        generate_sid unless options[:drop]
      end
    end
  end
end
