# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fast_ignore/version'

Gem::Specification.new do |spec|
  spec.name = 'fast_ignore'
  spec.version = FastIgnore::VERSION
  spec.authors = ['Dana Sherson']
  spec.email = ['robot@dana.sh']

  spec.summary = 'Parse gitignore files, quickly'
  spec.homepage = 'https://github.com/robotdana/fast_ignore'
  spec.license = 'MIT'

  spec.required_ruby_version = '~> 2.4'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  end

  spec.files = Dir.glob('lib/**/*') + ['CHANGELOG.md', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'leftovers', '>= 0.2.2'
  spec.add_development_dependency 'pry', '> 0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '>= 0.74.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 1'
  spec.add_development_dependency 'simplecov', '~> 0.18.5'
  spec.add_development_dependency 'spellr', '>= 0.8.3'
end
