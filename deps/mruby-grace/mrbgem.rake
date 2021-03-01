MRuby::Gem::Specification.new('mruby-grace') do |spec|
  spec.license = 'MIT'
  spec.authors = 'accaman'

  if File.exist? "#{ MRUBY_ROOT }/mrbgems/mruby-metaprog"
    spec.add_dependency "mruby-metaprog"
  end
  spec.add_dependency 'mruby-eval'
  spec.add_dependency 'mruby-object-ext'
  spec.add_dependency 'mruby-string-ext'
  spec.add_dependency 'mruby-symbol-ext'
  spec.add_dependency "mruby-r3", :github => "katzer/mruby-r3"

  spec.add_test_dependency "mruby-mtest"
end
