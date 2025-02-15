# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'path_list/version'

Gem::Specification.new do |spec|
  spec.name = 'path_list'
  spec.version = PathList::VERSION
  spec.authors = ['Dana Sherson']
  spec.email = ['robot@dana.sh']

  spec.summary = 'Parse gitignore files and rules, quickly'
  spec.homepage = 'https://github.com/robotdana/path_list'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 2.5.0'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = spec.homepage
    spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  end

  spec.files = Dir.glob('lib/**/*') + ['CHANGELOG.md', 'LICENSE.txt', 'README.md']
  spec.require_paths = ['lib']

  spec.metadata['rubygems_mfa_required'] = 'true'
end
