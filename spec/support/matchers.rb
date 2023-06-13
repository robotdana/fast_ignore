# frozen_string_literal: true

RSpec::Matchers.define(:match_files) do |*expected|
  match do |actual|
    @actual = actual.to_a

    if defined?($doing_include) && $doing_include
      expect(@actual).to allow_files(*expected)
    else
      expect(@actual).not_to allow_files(*expected)
    end

    true
  end

  match_when_negated do |actual|
    @actual = actual.to_a

    if defined?($doing_include) && $doing_include
      expect(@actual).not_to allow_files(*expected)
    else
      expect(@actual).to allow_files(*expected)
    end

    true
  end
end

RSpec::Matchers.define(:allow_files) do |*expected|
  match do |actual|
    @actual = actual.to_a
    expect(@actual).to include(*expected)
    if actual.respond_to?(:include?)
      expected.each do |path|
        expect(actual).to include(path)
      end
    end

    true
  end

  match_when_negated do |actual|
    @actual = actual.to_a
    expected.each do |path|
      expect(@actual).not_to include(path)
      expect(actual).not_to include(path) if actual.respond_to?(:include?)
    end

    true
  end
end

RSpec::Matchers.define(:allow_exactly) do |*expected|
  match do |actual|
    @actual = actual.to_a
    expect(@actual).to contain_exactly(*expected)
    expect(actual).to allow_files(*expected)

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

RSpec::Matchers.define(:have_default_inspect_value) do
  match do |actual|
    @actual = actual.inspect
    expect(@actual).to eq(default_inspect_value(actual))
  end
end

RSpec::Matchers.define(:have_instance_variables) do |expected|
  match do |actual|
    @actual = actual.instance_variables.to_h { |ivar| [ivar, actual.instance_variable_get(ivar)] }
    expect(@actual).to eq(expected)
  end
end
