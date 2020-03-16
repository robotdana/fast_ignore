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
    spec.metadata['source_code_uri'] = 'https://github.com/robotdana/fast_ignore'
    spec.metadata['changelog_uri'] = 'https://github.com/robotdana/fast_ignore/blob/master/CHANGELOG.md'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'pry', '> 0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '>= 0.74.0'
  spec.add_development_dependency 'rubocop-rspec', '~> 1'
  spec.add_development_dependency 'simplecov', '~> 0.18.5'
end
