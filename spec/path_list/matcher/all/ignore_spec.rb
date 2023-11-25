# frozen_string_literal: true

RSpec.describe PathList::Matcher::All::Ignore do
  subject { described_class.new(matchers) }

  let(:matcher_ignore_a) { instance_double(PathList::Matcher, 'matcher_ignore_a', weight: 1.1, polarity: :ignore) }
  let(:matcher_ignore_b) { instance_double(PathList::Matcher, 'matcher_ignore_b', weight: 2, polarity: :ignore) }
  let(:matcher_ignore_c) { instance_double(PathList::Matcher, 'matcher_ignore_c', weight: 3, polarity: :ignore) }
  let(:matcher_ignore_d) { instance_double(PathList::Matcher, 'matcher_ignore_d', weight: 4, polarity: :ignore) }

  let(:matchers) { [matcher_ignore_a, matcher_ignore_b, matcher_ignore_c] }

  it { is_expected.to be_frozen }

  # match is covered in ../all_spec.rb

  # build is covered in ../all_spec.rb
  describe '.build' do
    it 'delegates build to the All class' do
      allow(PathList::Matcher::All).to receive(:build).and_call_original
      expect(described_class.build([
        matcher_ignore_a,
        matcher_ignore_b,
        matcher_ignore_c
      ])).to be_like(
        described_class.new([
          matcher_ignore_a, matcher_ignore_b, matcher_ignore_c
        ])
      )
      expect(PathList::Matcher::All).to have_received(:build)
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matcher::All::Ignore.new([
          #{matcher_ignore_a.inspect},
          #{matcher_ignore_b.inspect},
          #{matcher_ignore_c.inspect}
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
    it 'is ignore' do
      expect(subject.polarity).to be :ignore
    end
  end

  describe '#squashable_with?' do
    it { is_expected.not_to be_squashable_with(subject.dup) }
  end

  describe '#dir_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_ignore_a).to receive(:dir_matcher).and_return(matcher_ignore_a)
      allow(matcher_ignore_b).to receive(:dir_matcher).and_return(matcher_ignore_b)
      allow(matcher_ignore_c).to receive(:dir_matcher).and_return(matcher_ignore_c)
      expect(subject.dir_matcher).to be subject
      expect(matcher_ignore_a).to have_received(:dir_matcher)
      expect(matcher_ignore_b).to have_received(:dir_matcher)
      expect(matcher_ignore_c).to have_received(:dir_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_ignore_a).to receive(:dir_matcher).and_return(matcher_ignore_a)
      allow(matcher_ignore_b).to receive(:dir_matcher).and_return(matcher_ignore_d)
      allow(matcher_ignore_c).to receive(:dir_matcher).and_return(matcher_ignore_c)
      new_matcher = subject.dir_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_ignore_a,
        matcher_ignore_c,
        matcher_ignore_d
      ]))
      expect(matcher_ignore_a).to have_received(:dir_matcher)
      expect(matcher_ignore_b).to have_received(:dir_matcher)
      expect(matcher_ignore_c).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_ignore_a).to receive(:file_matcher).and_return(matcher_ignore_a)
      allow(matcher_ignore_b).to receive(:file_matcher).and_return(matcher_ignore_b)
      allow(matcher_ignore_c).to receive(:file_matcher).and_return(matcher_ignore_c)
      expect(subject.file_matcher).to be subject
      expect(matcher_ignore_a).to have_received(:file_matcher)
      expect(matcher_ignore_b).to have_received(:file_matcher)
      expect(matcher_ignore_c).to have_received(:file_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_ignore_a).to receive(:file_matcher).and_return(matcher_ignore_a)
      allow(matcher_ignore_b).to receive(:file_matcher).and_return(matcher_ignore_d)
      allow(matcher_ignore_c).to receive(:file_matcher).and_return(matcher_ignore_c)
      new_matcher = subject.file_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_ignore_a,
        matcher_ignore_c,
        matcher_ignore_d
      ]))
      expect(matcher_ignore_a).to have_received(:file_matcher)
      expect(matcher_ignore_b).to have_received(:file_matcher)
      expect(matcher_ignore_c).to have_received(:file_matcher)
    end
  end
end
