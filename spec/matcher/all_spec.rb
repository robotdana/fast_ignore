# frozen_string_literal: true

RSpec.describe PathList::Matcher::All do
  subject { described_class.new(matchers) }

  let(:matcher_allow_a) { instance_double(PathList::Matcher, 'matcher_allow_a', weight: 1.1, polarity: :allow) }
  let(:matcher_allow_b) { instance_double(PathList::Matcher, 'matcher_allow_b', weight: 2.1, polarity: :allow) }
  let(:matcher_allow_c) { instance_double(PathList::Matcher, 'matcher_allow_c', weight: 3.1, polarity: :allow) }

  let(:matcher_ignore_a) { instance_double(PathList::Matcher, 'matcher_ignore_a', weight: 1.2, polarity: :ignore) }
  let(:matcher_ignore_b) { instance_double(PathList::Matcher, 'matcher_ignore_b', weight: 2.2, polarity: :ignore) }
  let(:matcher_ignore_c) { instance_double(PathList::Matcher, 'matcher_ignore_c', weight: 3.2, polarity: :ignore) }

  let(:matcher_mixed_a) { instance_double(PathList::Matcher, 'matcher_mixed_a', weight: 1.3, polarity: :mixed) }
  let(:matcher_mixed_b) { instance_double(PathList::Matcher, 'matcher_mixed_b', weight: 2.3, polarity: :mixed) }
  let(:matcher_mixed_c) { instance_double(PathList::Matcher, 'matcher_mixed_c', weight: 3.3, polarity: :mixed) }

  let(:matchers) { [matcher_allow_a, matcher_ignore_b, matcher_mixed_c] }

  it { is_expected.to be_frozen }

  describe '#match' do
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
            when [nil, :allow] then nil
            when [nil, :ignore] then :ignore
            when [:allow, :ignore] then :ignore
            when [nil, :allow, :ignore] then :ignore
            end
            # rubocop:enable Lint/DuplicateBranch

            it "returns #{result.inspect} when built from #{list}" do
              list = list.map.with_index do |(mock_result, polarity), index|
                instance_double(
                  PathList::Matcher, "matcher_#{index}", match: mock_result, polarity: polarity, weight: 0
                )
              end
              expect(described_class.build(list).match(instance_double(PathList::Candidate, 'candidate'))).to eq result
            end
          end
      end
    end
  end

  describe '.build' do
    it 'removes Blank matchers' do
      expect(described_class.build([
        PathList::Matcher::Blank,
        matcher_allow_a,
        matcher_ignore_a,
        PathList::Matcher::Blank,
        matcher_mixed_a,
        PathList::Matcher::Blank
      ])).to be_like(
        described_class.new([
          matcher_allow_a, matcher_ignore_a, matcher_mixed_a
        ])
      )
    end

    it 'returns Allow if there are no items' do
      expect(described_class.build([])).to be_like(PathList::Matcher::Allow)
    end

    it 'removes Allow matchers if there are other things' do
      expect(described_class.build([
        PathList::Matcher::Allow,
        matcher_allow_a,
        matcher_ignore_a,
        PathList::Matcher::Allow,
        matcher_mixed_a,
        PathList::Matcher::Allow
      ])).to be_like(
        described_class.new([
          matcher_allow_a, matcher_ignore_a, matcher_mixed_a
        ])
      )
    end

    it 'sorts items by weight ascending' do
      expect(described_class.build([
        matcher_allow_b,
        matcher_ignore_c,
        matcher_mixed_a
      ])).to be_like(
        described_class.new([
          matcher_mixed_a, matcher_allow_b, matcher_ignore_c
        ])
      )
    end

    it 'reduces Invalid matchers if there are other things' do
      expect(described_class.build([
        matcher_allow_a,
        matcher_ignore_a,
        PathList::Matcher::Invalid,
        matcher_mixed_a,
        PathList::Matcher::Invalid
      ])).to be_like(
        described_class.new([
          PathList::Matcher::Invalid, matcher_allow_a, matcher_ignore_a, matcher_mixed_a
        ])
      )
    end

    it 'returns Invalid if there are no other things' do
      expect(described_class.build([
        PathList::Matcher::Invalid,
        PathList::Matcher::Invalid,
        PathList::Matcher::Blank,
        PathList::Matcher::Invalid
      ])).to be_like(PathList::Matcher::Invalid)
    end

    it 'returns Ignore if there are any ignore' do
      expect(described_class.build([
        PathList::Matcher::Ignore,
        matcher_allow_a,
        matcher_ignore_a,
        matcher_mixed_a
      ])).to be_like(PathList::Matcher::Ignore)
    end

    it 'removes duplicates' do
      expect(described_class.build([
        PathList::Matcher::AllowAnyDir,
        matcher_allow_a,
        PathList::Matcher::AllowAnyDir,
        matcher_ignore_b
      ])).to be_like(described_class.new([
        PathList::Matcher::AllowAnyDir,
        matcher_allow_a,
        matcher_ignore_b
      ]))
    end

    it 'returns All::Two if there are only two' do
      expect(described_class.build([
        matcher_allow_a,
        matcher_ignore_b
      ])).to be_like(PathList::Matcher::All::Two.new([
        matcher_allow_a,
        matcher_ignore_b
      ]))
    end

    it 'returns All::Ignore if there are only ignore' do
      expect(described_class.build([
        matcher_ignore_b,
        matcher_ignore_a,
        matcher_ignore_c
      ])).to be_like(PathList::Matcher::All::Ignore.new([
        matcher_ignore_a,
        matcher_ignore_b,
        matcher_ignore_c
      ]))
    end

    it 'returns All::Allow if there are only allow' do
      expect(described_class.build([
        matcher_allow_b,
        matcher_allow_a,
        matcher_allow_c
      ])).to be_like(PathList::Matcher::All::Allow.new([
        matcher_allow_a,
        matcher_allow_b,
        matcher_allow_c
      ]))
    end

    it 'returns the matcher if there is only one' do
      expect(described_class.build([
        matcher_allow_b
      ])).to be(matcher_allow_b)
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matcher::All.new([
          #{matcher_allow_a.inspect},
          #{matcher_ignore_b.inspect},
          #{matcher_mixed_c.inspect}
        ])
      INSPECT
    end
  end

  describe '#weight' do
    it 'is the matchers plus 1' do
      expect(subject.weight).to eq 7.6
    end
  end

  describe '#polarity' do
    it 'is mixed' do
      expect(subject.polarity).to be :mixed
    end
  end

  describe '#squashable_with?' do
    it { is_expected.not_to be_squashable_with(subject.dup) }
  end

  describe '#dir_matcher' do
    let(:matchers) do
      [matcher_allow_a, matcher_ignore_b, matcher_mixed_c, matcher_allow_b]
    end

    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:dir_matcher).and_return(matcher_ignore_b)
      allow(matcher_mixed_c).to receive(:dir_matcher).and_return(matcher_mixed_c)
      allow(matcher_allow_b).to receive(:dir_matcher).and_return(matcher_allow_b)
      expect(subject.dir_matcher).to be subject
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_ignore_b).to have_received(:dir_matcher)
      expect(matcher_mixed_c).to have_received(:dir_matcher)
      expect(matcher_allow_b).to have_received(:dir_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:dir_matcher).and_return(matcher_ignore_b)
      allow(matcher_mixed_c).to receive(:dir_matcher).and_return(matcher_mixed_c)
      allow(matcher_allow_b).to receive(:dir_matcher).and_return(PathList::Matcher::Blank)
      new_matcher = subject.dir_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_ignore_b,
        matcher_mixed_c
      ]))
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_ignore_b).to have_received(:dir_matcher)
      expect(matcher_mixed_c).to have_received(:dir_matcher)
      expect(matcher_allow_b).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    let(:matchers) do
      [matcher_allow_a, matcher_ignore_b, matcher_mixed_c, matcher_allow_b]
    end

    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:file_matcher).and_return(matcher_ignore_b)
      allow(matcher_mixed_c).to receive(:file_matcher).and_return(matcher_mixed_c)
      allow(matcher_allow_b).to receive(:file_matcher).and_return(matcher_allow_b)
      expect(subject.file_matcher).to be subject
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_ignore_b).to have_received(:file_matcher)
      expect(matcher_mixed_c).to have_received(:file_matcher)
      expect(matcher_allow_b).to have_received(:file_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:file_matcher).and_return(matcher_ignore_b)
      allow(matcher_mixed_c).to receive(:file_matcher).and_return(matcher_mixed_c)
      allow(matcher_allow_b).to receive(:file_matcher).and_return(PathList::Matcher::Blank)
      new_matcher = subject.file_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_ignore_b,
        matcher_mixed_c
      ]))
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_ignore_b).to have_received(:file_matcher)
      expect(matcher_mixed_c).to have_received(:file_matcher)
      expect(matcher_allow_b).to have_received(:file_matcher)
    end
  end
end
