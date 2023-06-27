# frozen_string_literal: true

RSpec.describe PathList::Matchers::PathRegexp do
  subject { described_class.build(builder, polarity) }

  let(:polarity) { :allow }
  let(:builder) { PathList::RegexpBuilder.new({ 'a' => nil }) }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matchers::PathRegexp.new(/a/, :allow)' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 2.75) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }

    it 'is squashable with the same property values' do
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), :allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different allow value' do
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), :ignore)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), polarity)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(squashed).to be_like(described_class.build(PathList::RegexpBuilder.new({ 'a' => nil, 'b' => nil }),
                                                        polarity))
      expect(squashed).to be_like(described_class.new(/(?:a|b)/, polarity))
    end
  end

  describe '#match' do
    let(:path) { 'my/file.rb' }
    let(:builder) { PathList::RegexpBuilder.new(['file.rb']) }

    let(:candidate) do
      instance_double(PathList::Candidate, full_path: "/#{path}", full_path_downcase: "/#{path.downcase}")
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
end
