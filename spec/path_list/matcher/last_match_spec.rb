# frozen_string_literal: true

RSpec.describe PathList::Matcher::LastMatch do
  subject { described_class.new(matchers) }

  let(:matcher_allow_a) do
    instance_double(PathList::Matcher, 'matcher_allow_a', weight: 1.1, polarity: :allow, squashable_with?: false)
  end
  let(:matcher_allow_b) do
    instance_double(PathList::Matcher, 'matcher_allow_b', weight: 2.1, polarity: :allow, squashable_with?: false)
  end
  let(:matcher_allow_c) do
    instance_double(PathList::Matcher, 'matcher_allow_c', weight: 3.1, polarity: :allow, squashable_with?: false)
  end

  let(:matcher_ignore_a) do
    instance_double(PathList::Matcher, 'matcher_ignore_a', weight: 1.2, polarity: :ignore, squashable_with?: false)
  end
  let(:matcher_ignore_b) do
    instance_double(PathList::Matcher, 'matcher_ignore_b', weight: 2.2, polarity: :ignore, squashable_with?: false)
  end
  let(:matcher_ignore_c) do
    instance_double(PathList::Matcher, 'matcher_ignore_c', weight: 3.2, polarity: :ignore, squashable_with?: false)
  end

  let(:matcher_mixed_a) do
    instance_double(PathList::Matcher, 'matcher_mixed_a', weight: 1.3, polarity: :mixed, squashable_with?: false)
  end
  let(:matcher_mixed_b) do
    instance_double(PathList::Matcher, 'matcher_mixed_b', weight: 2.3, polarity: :mixed, squashable_with?: false)
  end
  let(:matcher_mixed_c) do
    instance_double(PathList::Matcher, 'matcher_mixed_c', weight: 3.3, polarity: :mixed, squashable_with?: false)
  end

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

            result = list.select(&:first).map(&:first).last

            it "returns #{result.inspect} when built from #{list}" do
              list = list.map do |(mock_result, polarity)|
                instance_double(
                  PathList::Matcher,
                  match: mock_result,
                  polarity: polarity,
                  weight: 0,
                  squashable_with?: false
                ).tap { |x| allow(x).to receive(:squash).and_return(x) }
              end

              expect(described_class.build(list).match(instance_double(PathList::Candidate))).to eq result
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

    it 'returns Blank if there are no items' do
      expect(described_class.build([])).to be_like(PathList::Matcher::Blank)
    end

    it 'removes things before the last Allow' do
      expect(described_class.build([
        PathList::Matcher::Allow,
        matcher_ignore_a,
        PathList::Matcher::Allow,
        matcher_mixed_a,
        matcher_mixed_b
      ])).to be_like(described_class.new([
        PathList::Matcher::Allow,
        matcher_mixed_a,
        matcher_mixed_b
      ]))
    end

    it 'removes things before the last Ignore' do
      expect(described_class.build([
        PathList::Matcher::Ignore,
        matcher_ignore_a,
        PathList::Matcher::Ignore,
        matcher_mixed_a,
        matcher_mixed_b
      ])).to be_like(described_class.new([
        PathList::Matcher::Ignore,
        matcher_mixed_a,
        matcher_mixed_b
      ]))
    end

    it 'maintains sort order' do
      expect(described_class.build([
        matcher_allow_b,
        matcher_ignore_c,
        matcher_mixed_a
      ])).to be_like(
        described_class.new([
          matcher_allow_b, matcher_ignore_c, matcher_mixed_a
        ])
      )
    end

    it 'removes Invalid matchers if there are other things' do
      expect(described_class.build([
        PathList::Matcher::Invalid,
        matcher_allow_a,
        matcher_ignore_a,
        PathList::Matcher::Invalid,
        matcher_mixed_a,
        PathList::Matcher::Invalid
      ])).to be_like(
        described_class.new([
          matcher_allow_a, matcher_ignore_a, matcher_mixed_a
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

    it 'removes duplicates next to each other' do
      expect(described_class.build([
        PathList::Matcher::AllowAnyDir,
        PathList::Matcher::AllowAnyDir,
        matcher_mixed_a,
        matcher_ignore_b
      ])).to be_like(described_class.new([
        PathList::Matcher::AllowAnyDir,
        matcher_mixed_a,
        matcher_ignore_b
      ]))
    end

    it "sorts items within polarity groups by weight descending (but doesn't sort mixed)" do
      expect(described_class.build([
        matcher_allow_a,
        matcher_allow_c,
        matcher_allow_b,
        matcher_ignore_b,
        matcher_ignore_a,
        matcher_ignore_c,
        matcher_mixed_b,
        matcher_mixed_a,
        matcher_mixed_c
      ])).to be_like(described_class.new([
        matcher_allow_c,
        matcher_allow_b,
        matcher_allow_a,
        matcher_ignore_c,
        matcher_ignore_b,
        matcher_ignore_a,
        matcher_mixed_b,
        matcher_mixed_a,
        matcher_mixed_c
      ]))
    end

    it 'merges items across polarity boundaries without sorting them' do
      expect(described_class.build([
        PathList::Matcher::MatchIfDir.new(matcher_allow_a),
        matcher_allow_c,
        PathList::Matcher::MatchIfDir.new(matcher_allow_b),
        PathList::Matcher::MatchIfDir.new(matcher_ignore_b),
        matcher_ignore_a,
        PathList::Matcher::MatchIfDir.new(matcher_ignore_c),
        matcher_mixed_b,
        matcher_mixed_a,
        matcher_mixed_c
      ])).to be_like(described_class.new([
        matcher_allow_c,
        PathList::Matcher::MatchIfDir.new(
          described_class.new([
            matcher_allow_b,
            matcher_allow_a,
            matcher_ignore_c,
            matcher_ignore_b
          ])
        ),
        matcher_ignore_a,
        matcher_mixed_b,
        matcher_mixed_a,
        matcher_mixed_c
      ]))
    end

    it 'removes duplicates in the same polarity chunk' do
      expect(described_class.build([
        PathList::Matcher::AllowAnyDir,
        matcher_allow_a,
        PathList::Matcher::AllowAnyDir,
        matcher_ignore_b
      ])).to be_like(described_class.new([
        matcher_allow_a,
        PathList::Matcher::AllowAnyDir,
        matcher_ignore_b
      ]))
    end

    it 'returns LastMatch::Two if there are only two' do
      expect(described_class.build([
        matcher_allow_a,
        matcher_ignore_b
      ])).to be_like(PathList::Matcher::LastMatch::Two.new([
        matcher_allow_a,
        matcher_ignore_b
      ]))
    end

    it 'returns LastMatch::Ignore if there are only ignore' do
      expect(described_class.build([
        matcher_ignore_b,
        matcher_ignore_a,
        matcher_ignore_c
      ])).to be_like(PathList::Matcher::LastMatch::Ignore.new([
        matcher_ignore_c,
        matcher_ignore_b,
        matcher_ignore_a
      ]))
    end

    it 'returns LastMatch::Allow if there are only allow' do
      expect(described_class.build([
        matcher_allow_b,
        matcher_allow_a,
        matcher_allow_c
      ])).to be_like(PathList::Matcher::LastMatch::Allow.new([
        matcher_allow_c,
        matcher_allow_b,
        matcher_allow_a
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
        PathList::Matcher::LastMatch.new([
          #{matcher_allow_a.inspect},
          #{matcher_ignore_b.inspect},
          #{matcher_mixed_c.inspect}
        ])
      INSPECT
    end
  end

  describe '#weight' do
    it 'is the matchers halved' do
      expect(subject.weight).to eq 3.3
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
