# frozen_string_literal: true

RSpec.describe PathList::Matcher::MatchUnlessDir do
  subject { described_class.build(matcher) }

  let(:polarity) { :allow }
  let(:matcher) do
    instance_double(
      PathList::Matcher,
      'matcher',
      polarity: polarity,
      match: polarity,
      weight: 10,
      squashable_with?: false
    )
  end

  it { is_expected.to be_frozen }

  describe '.build' do
    it 'is Blank when the matcher is Blank' do
      expect(described_class.build(PathList::Matcher::Blank)).to be PathList::Matcher::Blank
    end
  end

  describe '#match' do
    let(:directory) { false }
    let(:candidate) do
      instance_double(PathList::Candidate, 'candidate', directory?: directory)
    end

    context 'with a non-directory candidate' do
      context 'when allowing' do
        it do
          expect(subject.match(candidate)).to be :allow
          expect(matcher).to have_received(:match).with(candidate)
        end
      end

      context 'when not allowing' do
        let(:polarity) { :ignore }

        it do
          expect(subject.match(candidate)).to be :ignore
          expect(matcher).to have_received(:match).with(candidate)
        end
      end
    end

    context 'with a directory candidate' do
      let(:directory) { true }

      it do
        expect(subject.match(candidate)).to be_nil
        expect(matcher).not_to have_received(:match)
      end
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matcher::MatchUnlessDir.new(
          #{matcher.inspect}
        )
      INSPECT
    end
  end

  describe '#weight' do
    # weight of matcher * 0.8 + 1
    it { is_expected.to have_attributes(weight: 9) }
  end

  describe '#polarity' do
    context 'when polarity of matcher is ignore' do
      let(:polarity) { :ignore }

      it { is_expected.to have_attributes(polarity: :ignore) }
    end

    context 'when polarity of matcher is allow' do
      let(:polarity) { :allow }

      it { is_expected.to have_attributes(polarity: :allow) }
    end

    context 'when polarity of matcher is mixed' do
      let(:polarity) { :mixed }

      it { is_expected.to have_attributes(polarity: :mixed) }
    end
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matcher::Allow) }

    it 'is squashable with the other MatchIfDir matchers' do
      other = described_class.new(PathList::Matcher::Allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with AllowAnyDir' do
      expect(subject).not_to be_squashable_with(PathList::Matcher::AllowAnyDir)
    end
  end

  describe '#squash' do
    it 'squashes the matchers together' do
      subject
      other_matcher = instance_double(
        PathList::Matcher, 'other_matcher', weight: 2, polarity: :ignore, squashable_with?: false
      )
      other = described_class.new(other_matcher)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other], true)

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      squashed_matcher = PathList::Matcher::LastMatch::Two.new([
        matcher,
        other_matcher
      ])

      expect(squashed).to be_like(described_class.new(squashed_matcher))
    end
  end

  describe '#dir_matcher' do
    it 'returns Blank' do
      allow(matcher).to receive(:dir_matcher).and_return(matcher)
      expect(subject.dir_matcher).to be PathList::Matcher::Blank
      expect(matcher).not_to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'returns the matcher after passing dir_matcher to it' do
      allow(matcher).to receive(:file_matcher).and_return(matcher)
      expect(subject.file_matcher).to be matcher
      expect(matcher).to have_received(:file_matcher)
    end

    it 'passes to the matcher and returns Blank if the matcher does' do
      allow(matcher).to receive(:file_matcher).and_return(PathList::Matcher::Blank)
      expect(subject.file_matcher).to be PathList::Matcher::Blank
      expect(matcher).to have_received(:file_matcher)
    end
  end
end
