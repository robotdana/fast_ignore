# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'spellr/rake_task'

RuboCop::RakeTask.new
RSpec::Core::RakeTask.new(:spec)
Spellr::RakeTask.generate_task

if RUBY_PLATFORM == 'java'
  task :leftovers do
    puts 'Skip leftovers on java'
  end
else
  require 'leftovers/rake_task'
  Leftovers::RakeTask.generate_task
end

ENV['COVERAGE'] = '1'
task lint: [:rubocop, :spellr, :leftovers, :build]
task default: [:spec, :lint]
