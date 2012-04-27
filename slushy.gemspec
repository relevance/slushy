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
  s.summary     = %q{Aussie kitchenhand}
  s.description = %q{Seattle.rb ROXORS}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }

  s.add_development_dependency 'fog', '1.3.1'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake', '~> 0.9.2.2'
end
