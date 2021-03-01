module MeltingPot
  class RouteInteractor
    def initialize(route_repository, route_class = Route, logger = Logger.new(STDERR))
      @route_repository = route_repository
      @route_class = route_class
      @logger = logger
    end

    def create(source, destination, scheme, auth_required)
      @route_class.new(:source => source, :destination => destination, :scheme => scheme, :auth_required => auth_required)
        .tap { |route| @route_repository.create(route).join }
    end

    def find_all
      raise NotImplementedError
    end

    def find(id)
      @route_repository.find(id).join
    end

    def update(id, fields = {})
      raise NotImplementedError
    end

    def delete(id)
      @route_repository.delete(id).join
    end
  end
end