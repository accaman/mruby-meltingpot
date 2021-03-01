
module MeltingPot
  class RouteController
    def initialize(route_interactor, logger = Logger.new(STDERR))
      @route_interactor = route_interactor
      @logger = logger
    end

    def index
      raise NotImplementedError
    end

    def show(source, _req = nil)
      route = @route_interactor.find(source)
      if route.nil?
        return JsonResponse.new({ :message => "Not Found" }, 404)
      end
      JsonResponse.new(route.to_h)
    end

    # TODO, Refactoring
    def create(req)
      errors = []

      source = req.params["source"]
      if source.blank?
        errors << "missing parameter (source)" 
      elsif @route_interactor.find(source)
        errors << "a route already exists: #{ source }"
      end

      destination = req.params["destination"]
      if destination.blank?
        errors << "missing parameter (destination)" 
      end

      auth_required = req.params["auth_required"]
      if auth_required.blank?
        errors << "missing parameter (auth_required)" 
      end

      scheme = req.params["scheme"]
      if scheme.blank?
        scheme = nil # XXX, sanitize
      elsif ! (scheme == "https" || scheme == "http")
        errors << "scheme must be either https or http: #{ scheme }" 
      end

      if errors.present?
        return JsonResponse.new({ :message => "Validation Failed", :errors  => errors }, 422)
      end
      route = @route_interactor.create(source, destination, scheme, auth_required.to_b)

      JsonResponse.new(route.to_h, 201)
    end

    def update(source, _req = nil)
      raise NotImplementedError
    end

    def destroy(source, _ = nil)
      if @route_interactor.delete(source)
        JsonResponse.new(nil, 204)
      else
        JsonResponse.new({ :message => "Not Found" }, 404)
      end
    end
  end
end