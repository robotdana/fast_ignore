# frozen_string_literal: true

RSpec.describe PathList::Matcher::Mutable do
  subject { described_class.build(matcher) }

  let(:polarity) { :allow }
  let(:matcher) do
    instance_double(
      PathList::Matcher,
      'matcher',
      polarity: polarity,
      match: polarity,
      weight: 6,
      squashable_with?: false
    )
  end

  it { is_expected.not_to be_frozen }

  describe '#match' do
    let(:candidate) do
      instance_double(PathList::Candidate, 'candidate')
    end

    context 'with a directory candidate' do
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
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matcher::Mutable.new(
          #{matcher.inspect}
        )
      INSPECT
    end
  end

  describe '#weight' do
    # weight of matcher * 0.2 + 1
    it { is_expected.to have_attributes(weight: 7) }
  end

  describe '#polarity' do
    context 'when polarity of matcher is ignore' do
      let(:polarity) { :ignore }

      it { is_expected.to have_attributes(polarity: :mixed) }
    end

    context 'when polarity of matcher is allow' do
      let(:polarity) { :allow }

      it { is_expected.to have_attributes(polarity: :mixed) }
    end

    context 'when polarity of matcher is mixed' do
      let(:polarity) { :mixed }

      it { is_expected.to have_attributes(polarity: :mixed) }
    end
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matcher::Allow) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject], false)).to be subject
    end
  end

  describe '#dir_matcher' do
    it 'passes to the matcher and returns self' do
      allow(matcher).to receive(:dir_matcher)
      expect(subject.dir_matcher).to be subject
      expect(matcher).to have_received(:dir_matcher)
    end

    it 'passes to the matcher and replaces its matcher with the response, and returns self' do
      allow(matcher).to receive(:dir_matcher).and_return(PathList::Matcher::Blank)
      expect(subject.dir_matcher).to be subject
      expect(subject.matcher).to be PathList::Matcher::Blank
      expect(matcher).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'passes to the matcher and returns self' do
      allow(matcher).to receive(:file_matcher)
      expect(subject.file_matcher).to be subject
      expect(matcher).to have_received(:file_matcher)
    end

    it 'passes to the matcher and replaces its matcher with the response, and returns self' do
      allow(matcher).to receive(:file_matcher).and_return(PathList::Matcher::Blank)
      expect(subject.file_matcher).to be subject
      expect(subject.matcher).to be PathList::Matcher::Blank
      expect(matcher).to have_received(:file_matcher)
    end
  end
end
