# frozen_string_literal: true

require 'simplecov-console'

SimpleCov.start do
  add_filter '/spec/'

  enable_coverage(:branch)
  minimum_coverage line: 100, branch: 100

  self.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::Console
  ])
end
