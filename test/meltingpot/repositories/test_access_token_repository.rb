class TestAccessToeknRepository < MTest::Unit::TestCase
  def test
    exp = MeltingPot::BearerToken.new(
      :access_token => SecureRandom.base64( 24 ),
      :token_type   => "Bearer"                 ,
      :expires      => Time.now + 3600          ,
      :user_id      => "johndoe"
    )

    # test create
    access_token_repository.create( exp ).join
    act = access_token_repository.find( exp.id ).join
    assert_equal( exp.access_token, act.access_token )
    assert_equal( exp.token_type  , act.token_type )
    assert_equal( exp.expires.to_s, act.expires.to_s )
    assert_equal( exp.user_id     , act.user_id )

    # test delete
    access_token_repository.delete( exp.id ).join
    assert_nil( access_token_repository.find( exp.id ).join )
  end

  def access_token_repository
    @access_token_repository ||= MeltingPot::AccessTokenRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end
end
MTest::Unit.new.run
