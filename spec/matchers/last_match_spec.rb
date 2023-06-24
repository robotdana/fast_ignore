# frozen_string_literal: true

RSpec.describe PathList::Matchers::LastMatch do
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

            result = list.map(&:first).compact.last

            it "returns #{result.inspect} when built from #{list}" do
              list = list.map do |(mock_result, polarity)|
                instance_double(PathList::Matchers::Base, match: mock_result, polarity: polarity, weight: 0,
squashable_with?: false).tap { |x| allow(x).to receive(:squash).and_return(x) }
              end
              expect(described_class.build(list).match(instance_double(PathList::Candidate))).to eq result
            end
          end
      end
    end
  end
end
