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
    it("PathList.ignore(#{(base_pattern = described_class.gitignore(i)).inspect})") do
      expect { |pattern| PathList.ignore(pattern) }
        .to pass_or_find_simplified_failing_case(base_pattern)
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it("PathList.only(#{(base_pattern = described_class.gitignore(i)).inspect})") do
      expect { |pattern| PathList.only(pattern) }
        .to pass_or_find_simplified_failing_case(base_pattern)
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it("PathList.only(#{(base_pattern = described_class.gitignore(i)).inspect}, format: :glob_gitignore)") do
      expect { |pattern| PathList.only(pattern, format: :glob_gitignore) }
        .to pass_or_find_simplified_failing_case(base_pattern)
    end
  end

  ENV.fetch('FUZZ_ITERATIONS', '100').to_i.times do |i|
    it("PathList.ignore(#{(base_pattern = described_class.gitignore(i)).inspect}, format: :glob_gitignore)") do
      expect { |pattern| PathList.ignore(pattern, format: :glob_gitignore) }
        .to pass_or_find_simplified_failing_case(base_pattern)
    end
  end

  it('simplifies strings correctly') do
    expect { |pattern| raise if pattern.match?(/za+z/) }
      .not_to pass_or_find_simplified_failing_case('z' + ('a' * 20) + 'z')
    # expect simplified case to be zaz

    expect { |pattern| raise unless pattern.match?(/za+z/) }
      .to pass_or_find_simplified_failing_case('z' + ('a' * 20) + 'z')
  end

  base_pattern =
    "?:.ર֊# ?թ /ଛӊ ੈ࿙.࣯̃-^ೣ~. £ கӘ/[Ǒ܍*ஓඣ#ٌ#.ि \n~#/!ۓா?//Հ૯^[ཆ]ķ^ࠢ\\-༓^  न#]४#"
  it do
    expect { |pattern| PathList.ignore(pattern) }
      .to pass_or_find_simplified_failing_case(base_pattern)
  end

  it do
    expect { |pattern| PathList.only(pattern) }
      .to pass_or_find_simplified_failing_case(base_pattern)
  end

  it do
    expect { |pattern| PathList.only(pattern, format: :glob_gitignore) }
      .to pass_or_find_simplified_failing_case(base_pattern)
  end

  it do
    expect { |pattern| PathList.ignore(pattern, format: :glob_gitignore) }
      .to pass_or_find_simplified_failing_case(base_pattern)
  end
end
