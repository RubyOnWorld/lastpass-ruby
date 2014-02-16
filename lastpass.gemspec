# Copyright (C) 2013 Dmitry Yakimenko (detunized@gmail.com).
# Licensed under the terms of the MIT license. See LICENCE for details.

$:.push File.expand_path("../lib", __FILE__)
require "lastpass/version"

Gem::Specification.new do |s|
    s.name        = "lastpass"
    s.version     = LastPass::VERSION
    s.licenses    = ["MIT"]
    s.authors     = ["Dmitry Yakimenko"]
    s.email       = "detunized@gmail.com"
    s.homepage    = "https://github.com/detunized/lastpass-ruby"
    s.summary     = "Unofficial LastPass API"
    s.description = "Unofficial LastPass API"

    s.required_ruby_version = ">= 1.9.3"

    s.add_dependency "httparty", "~> 0.13.0"
    s.add_dependency "pbkdf2-ruby", "~> 0.2.0"

    s.add_development_dependency "rake", "~> 10.1.0"
    s.add_development_dependency "rspec", "~> 2.14.0"
    s.add_development_dependency "coveralls", "~> 0.7.0"

    s.files         = `git ls-files`.split "\n"
    s.test_files    = `git ls-files spec`.split "\n"
    s.require_paths = ["lib"]
end
