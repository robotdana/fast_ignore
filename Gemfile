# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group(:development) do
  platforms(:ruby) do
    if RUBY_VERSION.to_f >= 2.6
      gem 'benchmark-ips'
      gem 'commonmarker'
      gem 'debug'
      gem 'leftovers', '>= 0.4.0'
      gem 'pry'
      gem 'rake', '>= 12.3.3'
      gem 'rdoc'
      gem 'rubocop', '>= 0.93.1'
      gem 'rubocop-performance'
      gem 'rubocop-rake'
      gem 'rubocop-rspec', '>= 1.44.1'

      if RUBY_VERSION.to_i >= 3
        gem 'ruby-prof', '>= 1.7.1'
        gem 'ruby-prof-flamegraph', git: 'https://github.com/oozou/ruby-prof-flamegraph.git', ref: 'fc3c437'
      end
      gem 'simplecov', '~> 0.18.5'
      gem 'simplecov-console'
      gem 'spellr', '>= 0.8.3'

      gem 'yard'
    end
  end
  gem 'rspec', '~> 3.0'
end

gemspec
