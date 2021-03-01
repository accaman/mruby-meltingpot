module MeltingPot
  class Route < MiniDSL
    field :source       , :type => String, :present => true
    field :destination  , :type => String, :present => true
    field :scheme       , :type => String, :present => false
    field :auth_required #, :type => Boolean, :present => true

    alias :id :source
  end
end