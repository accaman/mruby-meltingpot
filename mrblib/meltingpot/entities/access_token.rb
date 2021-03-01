module MeltingPot
  class BearerToken < MiniDSL
    field :access_token, :type => String, :present => true
    field :token_type  , :type => String, :present => true
    field :expires     , :type => Time  , :present => true
    field :user_id     , :type => String, :present => true

    alias :id :access_token

    ACCESS_TOKEN_LEN = 256 / 8 * 3 / 4

    def self.create(time_to_live, user_id)
      new(
        :access_token => SecureRandom.base64(ACCESS_TOKEN_LEN),
        :token_type => "Bearer",
        :expires => Time.now + time_to_live,
        :user_id => user_id
      )
    end

    def verify
      true
    end
  end
end