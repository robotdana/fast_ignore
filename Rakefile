# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'spellr/rake_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)
Spellr::RakeTask.generate_task

default_tasks = if RUBY_PLATFORM == 'java'
  [:spec, :build]
else
  require 'leftovers/rake_task'
  Leftovers::RakeTask.generate_task

  ENV['COVERAGE'] = '1'
  [:spec, :rubocop, :spellr, :leftovers, :build]
end

task default: default_tasks
