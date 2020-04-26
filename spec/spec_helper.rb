# frozen_string_literal: true

require 'fileutils'
FileUtils.rm_rf(File.join(__dir__, '..', 'coverage'))

require 'bundler/setup'

require 'simplecov' if RUBY_PLATFORM != 'java'
require 'fast_ignore'

require_relative 'support/temp_dir_helper'
require_relative 'support/matchers'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
    c.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |c|
    c.verify_partial_doubles = true
  end

  config.example_status_persistence_file_path = '.rspec_status'
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.warnings = true
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
