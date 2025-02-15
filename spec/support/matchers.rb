# frozen_string_literal: true

RSpec::Matchers.define(:match_files) do |*expected, create: true|
  match do |actual|
    raise "Can't expect non-relative file, we actually have to make them" if create && expected.any? do |x|
      x.match?(%r{\A(\.\.|/)})
    end

    create_file_list(*expected) if create

    @actual = actual.to_a

    if defined?($doing_include) && $doing_include
      expect(@actual).to allow_files(*expected, create: false)
    else
      expect(@actual).not_to allow_files(*expected, create: false)
    end

    true
  end

  match_when_negated do |actual|
    raise "Can't expect non-relative file, we actually have to make them" if create && expected.any? do |x|
      x.match?(%r{\A(\.\.|/)})
    end

    create_file_list(*expected) if create

    @actual = actual.to_a

    if defined?($doing_include) && $doing_include
      expect(actual).not_to allow_files(*expected, create: false)
    else
      expect(actual).to allow_files(*expected, create: false)
    end

    true
  end
end

RSpec::Matchers.define(:allow_files) do |*expected, create: true|
  match do |actual|
    raise "Can't expect non-relative file, we actually have to make them" if create && expected.any? do |x|
      x.match?(%r{\A(\.\.|/)})
    end

    create_file_list(*expected) if create

    @actual = actual.to_a
    expect(@actual).to include(*expected)

    unless actual.is_a?(RealGit)
      expected.each do |path|
        expect(actual).to include(path)
      end
    end

    true
  end

  match_when_negated do |actual|
    raise "Can't expect non-relative file, we actually have to make them" if create && expected.any? do |x|
      x.match?(%r{\A(\.\.|/)})
    end

    create_file_list(*expected) if create

    @actual = actual.to_a

    expected.each do |path|
      expect(@actual).not_to include(path)
      expect(actual).not_to include(path) unless actual.is_a?(RealGit)
    end

    true
  end
end

RSpec::Matchers.define(:allow_exactly) do |*expected|
  match do |actual|
    @actual = actual.to_a
    expect(@actual).to match_array(expected)
    expect(actual).to allow_files(*expected, create: false)

    true
  end
end

RSpec::Matchers.define(:have_inspect_value) do |expected|
  match do |actual|
    if actual.inspect.include?('anonymous') || expected.include?('anonymous')
      raise "Can't compare inspect values of anonymous instance doubles"
    end

    @actual = actual.inspect
    expect(@actual).to eq(expected)

    true
  end
end

RSpec::Matchers.define(:have_instance_variables) do |expected| # leftovers:keep
  match do |actual|
    @actual = actual.instance_variables.to_h { |ivar| [ivar, actual.instance_variable_get(ivar)] }
    expect(@actual).to match(expected)
  end
end

RSpec::Matchers.define(:be_like) do |expected|
  match do |actual|
    if actual.inspect.include?('anonymous') || expected.inspect.include?('anonymous')
      raise "Can't compare inspect values of anonymous instance doubles"
    end

    expect(actual.inspect).to eq(expected.inspect)

    true
  end

  diffable
end

RSpec::Matchers.define(:pass_or_find_simplified_failing_case) do |string|
  match do |block|
    required_for_error = +''
    rest = string.dup
    puts rest.inspect
    @actual = rest
    begin
      block.call(rest)
    rescue StandardError
      nil
    else
      return true
    end

    until rest.empty?
      char_under_test = rest.slice!(0)
      candidate = required_for_error + rest

      begin
        block.call(candidate)
      rescue StandardError
        nil
      else
        required_for_error << char_under_test
      end
    end

    @actual = required_for_error
    expect { block.call(required_for_error) }.not_to raise_error
  end

  failure_message do |actual|
    "expected #{actual.inspect} to pass (simplified from #{expected.inspect})"
  end

  diffable

  def supports_block_expectations?
    true
  end
end
