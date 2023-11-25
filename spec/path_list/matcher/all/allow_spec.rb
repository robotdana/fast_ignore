# frozen_string_literal: true

RSpec.describe PathList::Matcher::All::Allow do
  subject { described_class.new(matchers) }

  let(:matcher_allow_a) { instance_double(PathList::Matcher, 'matcher_allow_a', weight: 1.1, polarity: :allow) }
  let(:matcher_allow_b) { instance_double(PathList::Matcher, 'matcher_allow_b', weight: 2, polarity: :allow) }
  let(:matcher_allow_c) { instance_double(PathList::Matcher, 'matcher_allow_c', weight: 3, polarity: :allow) }
  let(:matcher_allow_d) { instance_double(PathList::Matcher, 'matcher_allow_d', weight: 4, polarity: :allow) }

  let(:matchers) { [matcher_allow_a, matcher_allow_b, matcher_allow_c] }

  it { is_expected.to be_frozen }

  # match is covered in ../all_spec.rb

  # build is covered in ../all_spec.rb
  describe '.build' do
    it 'delegates build to the All class' do
      allow(PathList::Matcher::All).to receive(:build).and_call_original
      expect(described_class.build([
        matcher_allow_a,
        matcher_allow_b,
        matcher_allow_c
      ])).to be_like(
        described_class.new([
          matcher_allow_a, matcher_allow_b, matcher_allow_c
        ])
      )
      expect(PathList::Matcher::All).to have_received(:build)
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matcher::All::Allow.new([
          #{matcher_allow_a.inspect},
          #{matcher_allow_b.inspect},
          #{matcher_allow_c.inspect}
        ])
      INSPECT
    end
  end

  describe '#weight' do
    it 'is the matchers plus 1' do
      expect(subject.weight).to eq 7.1
    end
  end

  describe '#polarity' do
    it 'is allow' do
      expect(subject.polarity).to be :allow
    end
  end

  describe '#squashable_with?' do
    it { is_expected.not_to be_squashable_with(subject.dup) }
  end

  describe '#dir_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:dir_matcher).and_return(matcher_allow_b)
      allow(matcher_allow_c).to receive(:dir_matcher).and_return(matcher_allow_c)
      expect(subject.dir_matcher).to be subject
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_allow_b).to have_received(:dir_matcher)
      expect(matcher_allow_c).to have_received(:dir_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:dir_matcher).and_return(matcher_allow_d)
      allow(matcher_allow_c).to receive(:dir_matcher).and_return(matcher_allow_c)
      new_matcher = subject.dir_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_allow_c,
        matcher_allow_d
      ]))
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_allow_b).to have_received(:dir_matcher)
      expect(matcher_allow_c).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:file_matcher).and_return(matcher_allow_b)
      allow(matcher_allow_c).to receive(:file_matcher).and_return(matcher_allow_c)
      expect(subject.file_matcher).to be subject
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_allow_b).to have_received(:file_matcher)
      expect(matcher_allow_c).to have_received(:file_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:file_matcher).and_return(matcher_allow_d)
      allow(matcher_allow_c).to receive(:file_matcher).and_return(matcher_allow_c)
      new_matcher = subject.file_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_allow_c,
        matcher_allow_d
      ]))
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_allow_b).to have_received(:file_matcher)
      expect(matcher_allow_c).to have_received(:file_matcher)
    end
  end
end
