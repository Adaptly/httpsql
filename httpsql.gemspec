# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'httpsql/version'

Gem::Specification.new do |spec|
  spec.name          = "httpsql"
  spec.version       = Httpsql::VERSION
  spec.authors       = [ "Philip Champon", "Alejandro Ciniglio", "Sean Shillo" ]
  spec.email         = [ "philip@adaptly.com", "alejandro@adaptly.com", "sean@adaptly.com" ]
  spec.description   = %q{Expose model columns and ARel methods through query parameters in grape end points}
  spec.summary       = %q{Select model specified fields, create arbitrary queries, all using CGI query parameters}
  spec.homepage      = "https://github.com/Adaptly/httpsql"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 3.2"
  spec.add_dependency "arel", ">= 2.2"
  spec.add_dependency "grape", ">= 0.5.0"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "coveralls", ">= 0.5.7"
  spec.add_development_dependency "minitest", "~> 4.2"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "simplecov", ">= 0.7"
  spec.add_development_dependency "sqlite3"
end
