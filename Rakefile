# frozen_string_literal: true

# require 'bundler/gem_tasks'
require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'helix_runtime/build_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)
HelixRuntime::BuildTask.new do |t|
end

task test: [:build, :spec]
task default: [:build, :spec, :rubocop]
