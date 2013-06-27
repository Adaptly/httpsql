# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'httpsql/version'

Gem::Specification.new do |spec|
  spec.name          = "httpsql"
  spec.version       = Httpsql::VERSION
  spec.authors       = ["Sean Shillo", "Alejandro Ciniglio"]
  spec.email         = ["sean@adaptly.com", "alejandro@adaptly.com"]
  spec.description   = %q{Do sql over http}
  spec.summary       = %q{httpsql}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_dependency "activesupport"
end
