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

    unless actual.is_a?(ActualGitLSFiles)
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
      expect(actual).not_to include(path) unless actual.is_a?(ActualGitLSFiles)
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
    @actual = actual.inspect
    expect(@actual).to eq(expected)

    true
  end
end

# RSpec::Matchers.define(:have_instance_variables) do |expected|
#   match do |actual|
#     @actual = actual.instance_variables.to_h { |ivar| [ivar, actual.instance_variable_get(ivar)] }
#     expect(@actual).to match(expected)
#   end
# end

RSpec::Matchers.define(:be_like) do |expected|
  match do |actual|
    expect(actual.inspect).to eq(expected.inspect)

    true
  end

  diffable
end
