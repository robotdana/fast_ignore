# frozen_string_literal: true

RSpec.describe PathList::Matcher::Any::Two do
  subject { described_class.new(matchers) }

  let(:matcher_allow_a) do
    instance_double(PathList::Matcher, 'matcher_allow_a', weight: 1.1, polarity: :allow, squashable_with?: false)
  end

  let(:matcher_allow_b) do
    instance_double(PathList::Matcher, 'matcher_allow_b', weight: 2.1, polarity: :allow, squashable_with?: false)
  end

  let(:matcher_ignore_a) do
    instance_double(PathList::Matcher, 'matcher_ignore_a', weight: 1.2, polarity: :ignore, squashable_with?: false)
  end

  let(:matcher_ignore_b) do
    instance_double(PathList::Matcher, 'matcher_ignore_b', weight: 2.2, polarity: :ignore, squashable_with?: false)
  end

  let(:matcher_mixed_a) do
    instance_double(PathList::Matcher, 'matcher_mixed_a', weight: 1.3, polarity: :mixed, squashable_with?: false)
  end

  let(:matcher_mixed_b) do
    instance_double(PathList::Matcher, 'matcher_mixed_b', weight: 2.3, polarity: :mixed, squashable_with?: false)
  end

  let(:matchers) { [matcher_allow_a, matcher_ignore_b] }

  it { is_expected.to be_frozen }

  # match is covered in ../any_spec.rb

  # build is covered in ../any_spec.rb
  describe '.build' do
    it 'delegates build to the Any class' do
      allow(PathList::Matcher::Any).to receive(:build).and_call_original
      expect(described_class.build([
        matcher_allow_a,
        matcher_ignore_b
      ])).to be_like(
        described_class.new([
          matcher_allow_a, matcher_ignore_b
        ])
      )
      expect(PathList::Matcher::Any).to have_received(:build)
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matcher::Any::Two.new([
          #{matcher_allow_a.inspect},
          #{matcher_ignore_b.inspect}
        ])
      INSPECT
    end
  end

  describe '#weight' do
    it 'is the matchers halved' do
      expect(subject.weight).to be_within(0.001).of(1.65)
    end
  end

  describe '#polarity' do
    context "when the polarities don't match" do
      it 'is mixed' do
        expect(subject.polarity).to be :mixed
      end
    end

    context 'when the polarities are both allow' do
      let(:matchers) { [matcher_allow_a, matcher_allow_b] }

      it 'is allow' do
        expect(subject.polarity).to be :allow
      end
    end

    context 'when the polarities are both ignore' do
      let(:matchers) { [matcher_ignore_a, matcher_ignore_b] }

      it 'is ignore' do
        expect(subject.polarity).to be :ignore
      end
    end
  end

  describe '#squashable_with?' do
    it { is_expected.not_to be_squashable_with(subject.dup) }
  end

  describe '#dir_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:dir_matcher).and_return(matcher_ignore_b)
      expect(subject.dir_matcher).to be subject
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_ignore_b).to have_received(:dir_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:dir_matcher).and_return(matcher_ignore_a)
      new_matcher = subject.dir_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_ignore_a
      ]))
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_ignore_b).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:file_matcher).and_return(matcher_ignore_b)
      expect(subject.file_matcher).to be subject
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_ignore_b).to have_received(:file_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_ignore_b).to receive(:file_matcher).and_return(matcher_ignore_a)
      new_matcher = subject.file_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_ignore_a
      ]))
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_ignore_b).to have_received(:file_matcher)
    end
  end
end
