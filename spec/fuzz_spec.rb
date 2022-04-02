# frozen-string-literal: true

require_relative 'support/fuzz'

::RSpec.describe Fuzz do
  next if ENV['COVERAGE']

  around do |e|
    original_verbose = $VERBOSE
    $VERBOSE = false
    within_temp_dir { e.run }
    $VERBOSE = original_verbose
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it "ignore iteration #{i}" do
      gitignore = described_class.gitignore(i)
      puts gitignore

      expect do
        ::FastIgnore.new(relative: true, gitignore: false, ignore_rules: gitignore)
      end.not_to raise_error
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it "include iteration #{i}" do
      gitignore = described_class.gitignore(i)
      puts gitignore

      expect do
        ::FastIgnore.new(relative: true, gitignore: false, include_rules: gitignore)
      end.not_to raise_error
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it "argv iteration #{i}" do
      gitignore = described_class.gitignore(i)
      puts gitignore

      expect do
        ::FastIgnore.new(relative: true, gitignore: false, argv_rules: gitignore)
      end.not_to raise_error
    end
  end
end
