class TestRouteRepository < MTest::Unit::TestCase
  def test
    exp = MeltingPot::Route.new(
      :source        => "example.org",
      :destination   => "192.0.2.0"  ,
      :scheme        => nil          , # passthru
      :auth_required => true
    )

    # # test create
    route_repository.create( exp ).join
    act = route_repository.find( exp.id ).join
    assert_equal( exp.source       , act.source )
    assert_equal( exp.destination  , act.destination )
    assert_equal( exp.scheme       , act.scheme )
    assert_equal( exp.auth_required, act.auth_required )

    # test delete
    route_repository.delete( exp.id ).join
    assert_nil( route_repository.find( exp.id ).join )
  end

  def route_repository
    @route_repository ||= MeltingPot::RouteRepository.new( MeltingPot::TestRedis.new( "127.0.0.1", 6379 ) )
  end
end
MTest::Unit.new.run
