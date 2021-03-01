
class TestRouteInteractor < MTest::Unit::TestCase
  def test
    route_interactor.create("example.org", "192.0.2.0", nil, true)
    assert(route_interactor.find("example.org"))
    route_interactor.delete("example.org")
    assert_nil(route_interactor.find("exmaple.org"))
  end

  def route_interactor
    @route_interactor ||= MeltingPot::RouteInteractor.new(route_repository, MeltingPot::Route, Logger.new(File::NULL))
  end

  def route_repository
    @route_repository ||= MeltingPot::RouteRepository.new(MeltingPot::TestRedis.new("127.0.0.1", 6379))
  end
end
MTest::Unit.new.run
