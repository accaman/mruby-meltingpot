MRuby::Gem::Specification.new("mruby-meltingpot") do |spec|
  spec.license = "MIT"
  spec.authors = "accaman"

  if File.exist? "#{MRUBY_ROOT}/mrbgems/mruby-metaprog"
    spec.add_dependency "mruby-metaprog"
  end
  spec.add_dependency "mruby-rack"              , :path => "#{dir}/deps/mruby-rack"               # patched
  spec.add_dependency "mruby-rack-session-redis", :path => "#{dir}/deps/mruby-rack-session-redis"
  spec.add_dependency "mruby-grace"             , :path => "#{dir}/deps/mruby-grace"
  spec.add_dependency "mruby-minidsl"           , :path => "#{dir}/deps/mruby-minidsl"
  spec.add_dependency "mruby-secure-random"     , :path => "#{dir}/deps/mruby-secure-random"
  spec.add_dependency "mruby-env"
  spec.add_dependency "mruby-json"
  spec.add_dependency "mruby-logger" 
  spec.add_dependency "mruby-yaml"
  spec.rbfiles = [
    "#{dir}/mrblib/meltingpot.rb"                                     ,
    "#{dir}/mrblib/meltingpot/app.rb"                                 ,
    "#{dir}/mrblib/meltingpot/admin_app.rb"                           ,
    "#{dir}/mrblib/meltingpot/ext/object.rb"                          ,
    "#{dir}/mrblib/meltingpot/entities/user.rb"                       ,
    "#{dir}/mrblib/meltingpot/entities/access_token.rb"               ,
    "#{dir}/mrblib/meltingpot/entities/route.rb"                      ,
    "#{dir}/mrblib/meltingpot/repositories/user_repository.rb"        ,
    "#{dir}/mrblib/meltingpot/repositories/access_token_repository.rb",
    "#{dir}/mrblib/meltingpot/repositories/route_repository.rb"       ,
    "#{dir}/mrblib/meltingpot/interactors/user_interactor.rb"         ,
    "#{dir}/mrblib/meltingpot/interactors/access_token_interactor.rb" ,
    "#{dir}/mrblib/meltingpot/interactors/route_interactor.rb"        ,
    "#{dir}/mrblib/meltingpot/controllers/user_controller.rb"         ,
    "#{dir}/mrblib/meltingpot/controllers/access_token_controller.rb" ,
    "#{dir}/mrblib/meltingpot/controllers/route_controller.rb"        ,
    "#{dir}/mrblib/meltingpot/interactors/proxy_interactor.rb"        ,
    "#{dir}/mrblib/meltingpot/controllers/proxy_controller.rb"        ,
  ]

  spec.add_test_dependency "mruby-mtest"
  spec.add_test_dependency "mruby-redis", :github => "matsumotory/mruby-redis", :checksum_hash => "af40e42492c1a24ec88a15cd56eee9edc7e69788"
  spec.test_preload = "#{dir}/test/preload.rb"
  spec.test_rbfiles = [
    "#{dir}/test/test_meltingpot.rb"                                     ,
    "#{dir}/test/meltingpot/test_app.rb"                                 ,
    "#{dir}/test/meltingpot/test_admin_app.rb"                           ,
    "#{dir}/test/meltingpot/entities/test_user.rb"                       ,
    "#{dir}/test/meltingpot/entities/test_access_token.rb"               ,
    "#{dir}/test/meltingpot/entities/test_route.rb"                      ,
    "#{dir}/test/meltingpot/repositories/test_user_repository.rb"        ,
    "#{dir}/test/meltingpot/repositories/test_route_repository.rb"       ,
    "#{dir}/test/meltingpot/repositories/test_access_token_repository.rb",
    "#{dir}/test/meltingpot/interactors/test_user_interactor.rb"         ,
    "#{dir}/test/meltingpot/interactors/test_access_token_interactor.rb" ,
    "#{dir}/test/meltingpot/interactors/test_route_interactor.rb"       ,
    "#{dir}/test/meltingpot/controllers/test_user_controller.rb"         ,
    "#{dir}/test/meltingpot/controllers/test_access_token_controller.rb" ,
    "#{dir}/test/meltingpot/controllers/test_route_controller.rb"        ,
    "#{dir}/test/meltingpot/interactors/test_proxy_interactor.rb"        ,
    "#{dir}/test/meltingpot/controllers/test_proxy_controller.rb"        ,
  ]
end
