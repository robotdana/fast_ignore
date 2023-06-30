# frozen_string_literal: true

RSpec.describe PathList::Matchers::PathRegexp do
  subject { described_class.build(regexp_tokens, polarity).prepare }

  let(:polarity) { :allow }
  let(:regexp_tokens) { [['a']] }

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:path) { 'my/file.rb' }
    let(:regexp_tokens) { [['file.rb']] }

    let(:candidate) do
      instance_double(PathList::Candidate, 'candidate', full_path: "/#{path}", full_path_downcase: "/#{path.downcase}")
    end

    context 'with a matching rule' do
      context 'when allowing' do
        it { expect(subject.match(candidate)).to be :allow }
      end

      context 'when not allowing' do
        let(:polarity) { :ignore }

        it { expect(subject.match(candidate)).to be :ignore }
      end
    end

    context 'with a non-matching rule' do
      let(:path) { 'my/file.sh/' }

      context 'when allowing' do
        it { expect(subject.match(candidate)).to be_nil }
      end

      context 'when not allowing' do
        let(:polarity) { false }

        it { expect(subject.match(candidate)).to be_nil }
      end
    end
  end

  describe '#inspect' do
    it { expect(subject).to have_inspect_value 'PathList::Matchers::PathRegexp.new(/a/, :allow)' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 3.75) }
  end

  describe '#polarity' do
    context 'when polarity is ignore' do
      let(:polarity) { :ignore }

      it { is_expected.to have_attributes(polarity: :ignore) }
    end

    context 'when polarity is allow' do
      let(:polarity) { :allow }

      it { is_expected.to have_attributes(polarity: :allow) }
    end
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }

    it 'is squashable with the same polarity values' do
      other = described_class.build([['b']], :allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different polarity value' do
      other = described_class.build([['b']], :ignore)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.build([['b']], polarity)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other], true)

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(squashed).to be_like(described_class.new(/(?:a|b)/, polarity))
    end
  end

  describe '#without_matcher' do
    it 'returns Blank if matcher is self' do
      expect(subject.without_matcher(subject)).to be PathList::Matchers::Blank
    end

    it 'returns self otherwise' do
      expect(subject.without_matcher(PathList::Matchers::Blank)).to be subject
    end
  end

  describe '#dir_matcher' do
    it 'returns self' do
      expect(subject.dir_matcher).to be subject
    end
  end

  describe '#file_matcher' do
    it 'returns self' do
      expect(subject.file_matcher).to be subject
    end
  end
end
