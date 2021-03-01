MRuby::Gem::Specification.new('mruby-minidsl') do |spec|
  spec.license = 'MIT'
  spec.authors = 'accaman'

  # XXX, Move Kernel#send to mruby-metaprog in v2.0
  if File.exist? "#{MRUBY_ROOT}/mrbgems/mruby-metaprog"
    spec.add_dependency 'mruby-metaprog', :core => 'mruby-metaprog'
  end
end
