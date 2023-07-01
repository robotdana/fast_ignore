# frozen_string_literal: true

require_relative 'support/fuzz'

RSpec.describe Fuzz do
  next if ENV['COVERAGE']

  around do |e|
    original_verbose = $VERBOSE
    $VERBOSE = false
    e.run
  ensure
    $VERBOSE = original_verbose
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it "ignore iteration #{i}" do
      gitignore = described_class.gitignore(i)
      puts gitignore

      expect do
        PathList.ignore(gitignore)
      end.not_to raise_error
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it "include iteration #{i}" do
      gitignore = described_class.gitignore(i)
      puts gitignore

      expect do
        PathList.only(gitignore)
      end.not_to raise_error
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it "argv iteration #{i}" do
      gitignore = described_class.gitignore(i)
      puts gitignore

      expect do
        PathList.ignore(gitignore, format: :glob)
      end.not_to raise_error
    end
  end
end
