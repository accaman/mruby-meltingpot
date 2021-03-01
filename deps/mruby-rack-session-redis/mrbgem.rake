MRuby::Gem::Specification.new('mruby-rack-session-redis') do |spec|
  spec.license = 'MIT'
  spec.authors = 'accaman'

  # XXX, Move Kernel#send to mruby-metaprog in v2.0
  if File.exist?("#{MRUBY_ROOT}/mrbgems/mruby-metaprog")
    spec.add_dependency 'mruby-metaprog', :core => 'mruby-metaprog'
  end
  if File.exist?( File.expand_path("../../mruby-rack", __FILE__) )  
    spec.add_dependency "mruby-rack", :path => File.expand_path("../../mruby-rack", __FILE__)
  else
    spec.add_dependency "mruby-rack", :github => "i110/mruby-rack"
  end
  spec.add_dependency "mruby-json"

  spec.add_test_dependency "mruby-mtest"
  # XXX, mruby-redis has not backward compatibility
  spec.add_test_dependency "mruby-redis", :github => "matsumotory/mruby-redis", :checksum_hash => "af40e42492c1a24ec88a15cd56eee9edc7e69788"
  # wrap around redis methods to normalize with h2o::redis
  spec.test_preload = "#{dir}/test/preload.rb"
end