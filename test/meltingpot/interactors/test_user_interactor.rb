class TestUserInteractor < MTest::Unit::TestCase
  def test
    user_interactor.create("johndoe", "P@ssw0rd123456789")
    assert(user_interactor.find("johndoe"))
    user_interactor.delete("johndoe")
    assert_nil(user_interactor.find("johndoe"))
  end

  PASSWORD_PEPPER = SecureRandom.hex(32)

  def user_interactor
    @user_interactor ||= MeltingPot::UserInteractor.new( user_repository, MeltingPot::User, PASSWORD_PEPPER, Logger.new(File::NULL) )
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end
end
MTest::Unit.new.run