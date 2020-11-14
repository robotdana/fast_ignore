# frozen_string_literal: true

if RUBY_PLATFORM != 'java'
  module Warning # leftovers:allow
    def warn(msg) # leftovers:allow
      raise msg unless msg.include?('FastIgnore deprecation:')
    end
  end
end

$doing_include = false

require 'fileutils'
FileUtils.rm_rf(File.join(__dir__, '..', 'coverage'))

require 'bundler/setup'

require 'simplecov' if ENV['COVERAGE']
require 'fast_ignore'

require_relative 'support/temp_dir_helper'
require_relative 'support/stub_env_helper'
require_relative 'support/stub_file_helper'
require_relative 'support/stub_global_gitignore_helper'
require_relative 'support/matchers'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |c|
    c.verify_partial_doubles = true
  end

  config.before do
    stub_blank_global_config
  end

  config.example_status_persistence_file_path = '.rspec_status'
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.warnings = true
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
