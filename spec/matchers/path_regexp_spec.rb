# frozen_string_literal: true

RSpec.describe FastIgnore::Matchers::PathRegexp do
  subject { described_class.new(rule, squashable, dir_only, allow_value, implicit) }

  let(:rule) { /a/ }
  let(:squashable) { true }
  let(:dir_only) { true }
  let(:allow_value) { true }
  let(:implicit) { true }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    context 'when @dir_only' do
      it { is_expected.to have_inspect_value '#<FastIgnore::Matchers::PathRegexp dir_only :allow /a/>' }
    end

    context 'when not @dir_only' do
      let(:dir_only) { false }

      it { is_expected.to have_inspect_value '#<FastIgnore::Matchers::PathRegexp :allow /a/>' }
    end
  end

  describe '#dir_only?' do
    context 'when @dir_only' do
      it { is_expected.to be_dir_only }
    end

    context 'when not @dir_only' do
      let(:dir_only) { false }

      it { is_expected.not_to be_dir_only }
    end
  end

  describe '#file_only?' do
    it { is_expected.not_to be_file_only }
  end

  describe '#implicit?' do
    context 'when @implicit' do
      it { is_expected.to be_implicit }
    end

    context 'when not @implicit' do
      let(:implicit) { false }

      it { is_expected.not_to be_implicit }
    end
  end

  describe '#removable?' do
    it { is_expected.not_to be_removable }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(::FastIgnore::Matchers::AllowAnyParent) }

    it 'is squashable with the same property values' do
      other = described_class.new(/b/, squashable, dir_only, allow_value, implicit)

      expect(subject).to be_squashable_with(other)
    end

    context 'with squashable false' do
      let(:squashable) { false }

      it 'is not squashable even with the same property values' do
        other = described_class.new(/b/, squashable, dir_only, allow_value, implicit)

        expect(subject).not_to be_squashable_with(other)
      end

      it 'is not squashable even when other is "squashable" and has otherwise the same property values' do
        other = described_class.new(/b/, !squashable, allow_value, allow_value, implicit)

        expect(subject).not_to be_squashable_with(other)
      end
    end

    it 'is not squashable with a different dir_only value' do
      other = described_class.new(/b/, squashable, !dir_only, allow_value, implicit)

      expect(subject).not_to be_squashable_with(other)
    end

    it 'is not squashable with a different allow value' do
      other = described_class.new(/b/, squashable, dir_only, !allow_value, implicit)

      expect(subject).not_to be_squashable_with(other)
    end

    it 'is not squashable with a different implicit value' do
      other = described_class.new(/b/, squashable, dir_only, allow_value, !implicit)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.new(/b/, squashable, dir_only, allow_value, implicit)

      allow(described_class).to receive(:new)
        .with(/(?-mix:a)|(?-mix:b)/, squashable, dir_only, allow_value, implicit)
        .and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(described_class).to have_received(:new)
        .with(/(?-mix:a)|(?-mix:b)/, squashable, dir_only, allow_value, implicit)
    end
  end

  describe '#append' do
    it 'returns nil' do
      expect(subject.append(instance_double(::FastIgnore::Patterns))).to be_nil
    end
  end

  describe '#match' do
    let(:path) { 'my/file.rb' }
    let(:rule) { /\bfile.rb\b/ }

    let(:candidate) { instance_double(::FastIgnore::Candidate, path: path) }

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
      let(:rule) { /\bfile.sh\b/ }

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
