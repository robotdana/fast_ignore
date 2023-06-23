# frozen_string_literal: true

RSpec.describe PathList::Matchers::PathRegexp do
  subject { described_class.build(builder, allow_value) }

  let(:allow_value) { true }
  let(:builder) { PathList::RegexpBuilder.new(['a']) }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matchers::PathRegexp.new(/a/i, true)' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 3.0) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }

    it 'is squashable with the same property values' do
      other = described_class.build(PathList::RegexpBuilder.new(['b']), allow_value)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different allow value' do
      other = described_class.build(PathList::RegexpBuilder.new(['b']), !allow_value)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.build(PathList::RegexpBuilder.new(['b']), allow_value)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(squashed).to be_like(described_class.build(PathList::RegexpBuilder.new([[['a'], ['b']]]), allow_value))
      expect(squashed).to be_like(described_class.new(/(?:a|b)/i, allow_value))
    end
  end

  describe '#match' do
    let(:path) { 'my/file.rb' }
    let(:builder) { PathList::RegexpBuilder.new(['file.rb']) }

    let(:candidate) { instance_double(PathList::Candidate, full_path: "/#{path}") }

    context 'with a matching rule' do
      context 'when allowing' do
        it { expect(subject.match(candidate)).to be :allow }
      end

      context 'when not allowing' do
        let(:allow_value) { false }

        it { expect(subject.match(candidate)).to be :ignore }
      end
    end

    context 'with a non-matching rule' do
      let(:path) { 'my/file.sh/' }

      context 'when allowing' do
        it { expect(subject.match(candidate)).to be_nil }
      end

      context 'when not allowing' do
        let(:allow_value) { false }

        it { expect(subject.match(candidate)).to be_nil }
      end
    end
  end
end
