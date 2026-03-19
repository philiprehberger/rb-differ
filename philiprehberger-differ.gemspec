# frozen_string_literal: true

require_relative 'lib/philiprehberger/differ/version'

Gem::Specification.new do |spec|
  spec.name = 'philiprehberger-differ'
  spec.version = Philiprehberger::Differ::VERSION
  spec.authors = ['Philip Rehberger']
  spec.email = ['me@philiprehberger.com']

  spec.summary = 'Deep structural diff for hashes, arrays, and nested objects'
  spec.description = 'A Ruby library for deep structural diffing of hashes, arrays, and nested objects ' \
                     'with apply/revert, JSON Patch output, similarity scoring, and configurable ignore paths.'
  spec.homepage = 'https://github.com/philiprehberger/rb-differ'
  spec.license = 'MIT'
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"]       = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]
end
