# frozen_string_literal: true

RSpec.describe PathList::Matchers::Any do
  describe '.build' do
    return_values = [nil, :allow, :ignore]
    polarity_values = [:allow, :ignore, :mixed]
    [2, 3].each do |n|
      describe "#{n} item truth table" do
        return_values.repeated_permutation(n).to_a
          .product(polarity_values.repeated_permutation(n).to_a)
          .map { |(a, b)| a.zip(b) }
          .each do |list|
            # impossible polarities
            next if list.include?([:ignore, :allow]) || list.include?([:allow, :ignore])

            # actual truth table
            # rubocop:disable Lint/DuplicateBranch
            result = case list.map(&:first).uniq.sort_by(&:to_s)
            when [:allow] then :allow
            when [:ignore] then :ignore
            when [nil] then nil
            when [nil, :allow] then :allow
            when [nil, :ignore] then :ignore
            when [:allow, :ignore] then :allow
            when [nil, :allow, :ignore] then :allow
            end
            # rubocop:enable Lint/DuplicateBranch

            it "returns #{result.inspect} when built from #{list}" do
              list = list.map do |(mock_result, polarity)|
                instance_double(PathList::Matchers::Base, match: mock_result, polarity: polarity, weight: 0,
squashable_with?: false)
              end
              expect(described_class.build(list).match(instance_double(PathList::Candidate))).to eq result
            end
          end
      end
    end
  end
end
