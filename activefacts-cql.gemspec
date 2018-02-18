# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activefacts/cql/version'

Gem::Specification.new do |spec|
  spec.name          = "activefacts-cql"
  spec.version       = ActiveFacts::CQL::VERSION
  spec.authors       = ["Clifford Heath"]
  spec.email         = ["clifford.heath@gmail.com"]

  spec.summary       = %q{Compiler for the Constellation Query Language}
  spec.description   = %q{Compiler for the Constellation Query Language, part of the ActiveFacts suite for Fact Modeling}
  spec.homepage      = "http://github.com/cjheath/activefacts-cql"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.
    split("\x0").
    reject { |f| f.match(%r{^(test|spec|features)/}) }.
    map{|file| file.sub(/\.treetop$/,'.rb')}
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.10"
  spec.add_development_dependency "rake", "> 10"
  spec.add_development_dependency "rspec", "~> 3.3"

  spec.add_runtime_dependency "activefacts-metamodel", "~> 1", ">= 1.9.22"
  spec.add_runtime_dependency "treetop", ["~> 1.6", ">= 1.6.9"]
end
