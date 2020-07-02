# frozen_string_literal: true

$doing_include = false

RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec::Matchers.define(:match_files) do |*expected|
  match do |actual|
    @actual = actual.to_a

    if $doing_include
      expect(@actual).to allow_files(*expected)
    else
      expect(@actual).not_to allow_files(*expected)
    end

    true
  end

  match_when_negated do |actual|
    @actual = actual.to_a

    if $doing_include
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
    if actual.respond_to?(:allowed?)
      expected.each do |path|
        expect(actual).to be_allowed(path)
      end
    end

    true
  end

  match_when_negated do |actual|
    @actual = actual.to_a
    expected.each do |path|
      expect(@actual).not_to include(path)
      expect(actual).not_to be_allowed(path) if actual.respond_to?(:allowed?)
    end

    true
  end
end

RSpec::Matchers.define_negated_matcher(:exclude, :include)

RSpec::Matchers.define(:allow_exactly) do |*expected|
  match do |actual|
    @actual = actual.to_a
    expect(@actual).to contain_exactly(*expected)
    expect(actual).to allow_files(*expected)

    true
  end
end
