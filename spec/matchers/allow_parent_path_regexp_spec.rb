# frozen_string_literal: true

RSpec.describe PathList::Matchers::AllowParentPathRegexp do
  subject { described_class.new(rule) }

  let(:rule) { /a/ }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value '#<PathList::Matchers::AllowParentPathRegexp /a/>' }
  end

  describe '#dir_only?' do
    it { is_expected.to be_dir_only }
  end

  describe '#file_only?' do
    it { is_expected.not_to be_file_only }
  end

  describe '#implicit?' do
    it { is_expected.to be_implicit }
  end

  describe '#removable?' do
    it { is_expected.not_to be_removable }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(::PathList::Matchers::AllowAnyParent) }
    it { is_expected.to be_squashable_with(described_class.new(/b/)) }
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.new(/b/)

      allow(described_class).to receive(:new)
        .with(/(?-mix:a)|(?-mix:b)/)
        .and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(described_class).to have_received(:new)
        .with(/(?-mix:a)|(?-mix:b)/)
    end
  end

  describe '#append' do
    it 'returns nil' do
      expect(subject.append(instance_double(::PathList::Patterns))).to be_nil
    end
  end

  describe '#match' do
    let(:path) { 'a' }
    let(:directory) { true }
    let(:candidate) { instance_double(::PathList::Candidate, directory?: directory, path: path) }

    context 'when directory is true' do
      context 'when path matches the rule' do
        it { expect(subject.match(candidate)).to be :allow }
      end

      context "when path doesn't match the rule" do
        let(:path) { 'b' }

        it { expect(subject.match(candidate)).to be_nil }
      end
    end

    context 'when directory is false' do
      let(:directory) { false }

      it "is nil and doesn't try matching the path" do
        expect(subject.match(candidate)).to be_nil
        expect(candidate).not_to have_received(:path)
      end
    end
  end
end
