class TestUserRepository < MTest::Unit::TestCase
  def test
    exp = MeltingPot::User.new(
      :username           => "johndoe"       ,
      :encrypted_password => SecureRandom.hex( 32 ),
      :salt               => SecureRandom.hex( 32 )
    )

    # test create
    user_repository.create( exp ).join
    act = user_repository.find( exp.id ).join
    assert_equal( exp.username          , act.username )
    assert_equal( exp.encrypted_password, act.encrypted_password )
    assert_equal( exp.salt              , act.salt )

    # test delete
    user_repository.delete( exp.id ).join
    assert_nil( user_repository.find( exp.id ).join )
  end

  def user_repository
    @user_repository ||= MeltingPot::UserRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end
end
MTest::Unit.new.run
