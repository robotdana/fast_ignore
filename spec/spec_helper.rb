# frozen_string_literal: true

begin
  require 'simplecov'

  SimpleCov.start do
    add_filter '/backports/'
    add_filter '/spec/'
    enable_coverage(:branch)
  end
  SimpleCov.minimum_coverage 100
rescue LoadError
  nil # no simplecov for you
end

require 'bundler/setup'
require 'fast_ignore'

require_relative 'support/temp_dir_helper'

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
