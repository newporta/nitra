spec = Gem::Specification.new do |s|
  s.name = 'nitra'
  s.version = '1.0.10'
  s.platform = Gem::Platform::RUBY
  s.license = "MIT"
  s.homepage = "http://github.com/fluxfederation/nitra"
  s.summary = "Multi-process rspec runner"
  s.description = "Multi-process rspec runner"
  s.authors = ["Roger Nesbitt", "Andy Newport", "Jeremy Wells", "Will Bryant"]
  s.email = "roger@youdo.co.nz"

  s.bindir = 'bin'
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_path     = "lib"
  s.files = %w(README.md lib/nitra.rb bin/nitra) + Dir['lib/**/*.rb']
  s.test_files = `git ls-files -- {spec,features}/*`.split("\n")

  s.add_dependency('cucumber', '>= 1.1.9')
  s.add_dependency('rspec')

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-reporters'
end
