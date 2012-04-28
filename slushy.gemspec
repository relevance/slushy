# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "slushy/version"

Gem::Specification.new do |s|
  s.name        = "slushy"
  s.version     = Slushy::VERSION
  s.homepage    = "http://github.com/relevance/slushy"
  s.authors     = ["Sam Umbach", "Gabriel Horner", "Alex Redington"]
  s.email       = ["sam@thinkrelevance.com"]
  s.homepage    = "http://github.com/relevance/slushy"
  s.summary     = %q{An Aussie kitchen hand helping out Chef}
  s.description = "Giving Chef a hand in the provisional kitchen - Aussie style. Using Fog's API, creates an instance and converges chef recipes on it."

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.add_development_dependency 'fog', '1.3.1'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake', '~> 0.9.2.2'
  s.add_development_dependency 'bundler', '~> 1.1'
end
