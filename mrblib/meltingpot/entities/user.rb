module MeltingPot
  class User < MiniDSL
    field :username          , :type => String, :present => true
    field :encrypted_password, :type => String, :present => true
    field :salt              , :type => String, :present => true

    alias :id :username

    SALT_SIZE = 256 / 8

    def self.create(username, password)
      # Every salt should ideally have a long salt value of at least the same length as the output of the hash.
      # https://www.mcafee.com/blogs/enterprise/cloud-security/what-is-a-salt-and-how-does-it-make-password-hashing-more-secure/
      salt = SecureRandom.hex(SALT_SIZE)
      new(
        :username => username,
        :encrypted_password => encrypt_password(password, salt),
        :salt => salt
      )
    end

    def confirm_password(password)
      @encrypted_password == User.encrypt_password(password, @salt)
    end

    private

      def self.encrypt_password(password, salt)
        Digest::HMAC.hexdigest(password, salt, Digest::SHA256)
      end
  end
end