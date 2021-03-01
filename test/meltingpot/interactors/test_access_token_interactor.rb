class TestAccessTokenInteractor < MTest::Unit::TestCase
  def test
    user = MeltingPot::User.create("johndoe", "P@ssw0rd123456789#{ PASSWORD_PEPPER }")
    user_repository.create(user).join

    # verification failed
    assert_nil(access_token_interactor.acquire("johnsmith", "P@ssw0rd123456789"))
    assert_nil(access_token_interactor.acquire("johndoe", "password123456789"))

    # verification succeeded
    token = access_token_interactor.acquire("johndoe", "P@ssw0rd123456789")
    assert(token)

    disposed = access_token_interactor.dispose(token.access_token)
    assert(disposed)
  ensure
    user_repository.delete( user.username ).join
  end

  PASSWORD_PEPPER = SecureRandom.hex(32)

  def access_token_interactor
    @access_token_interactor ||= MeltingPot::AccessTokenInteractor.new(access_token_repository, user_repository, MeltingPot::BearerToken, 1, PASSWORD_PEPPER, ::Logger.new(File::NULL))
  end

  def access_token_repository
    @access_token_repository ||= MeltingPot::AccessTokenRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end
end
MTest::Unit.new.run