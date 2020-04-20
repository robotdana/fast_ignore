# frozen_string_literal: true

RSpec::Matchers.define(:allow) do |*expected|
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
end
RSpec::Matchers.define_negated_matcher(:exclude, :include)
RSpec::Matchers.define(:disallow) do |*expected|
  match do |actual|
    @actual = actual.to_a
    expect(@actual).to exclude(*expected)

    if actual.respond_to?(:allowed?)
      expected.each do |path|
        expect(actual).not_to be_allowed(path)
      end
    end

    true
  end
end

RSpec::Matchers.define(:allow_exactly) do |*expected|
  match do |actual|
    @actual = actual.to_a
    expect(@actual).to contain_exactly(*expected)

    if actual.respond_to?(:allowed?)
      expected.each do |path|
        expect(actual).to be_allowed(path)
      end
    end

    true
  end
end
