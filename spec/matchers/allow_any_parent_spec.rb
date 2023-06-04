# frozen_string_literal: true

RSpec.describe PathList::Matchers::AllowAnyParent do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value '#<PathList::Matchers::AllowAnyParent>' }
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
    it { is_expected.to have_attributes(weight: 0) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(::PathList::Matchers::List.new([])) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject])).to be subject
    end
  end

  describe '#eql?' do
    it { is_expected.to eq(subject) }
    it { is_expected.not_to eq(::PathList::Matchers::Unmatchable) }
  end

  describe '#append' do
    it 'returns nil' do
      expect(subject.append(instance_double(::PathList::Patterns))).to be_nil
    end
  end

  describe '#match' do
    let(:directory) { true }
    let(:candidate) { instance_double(::PathList::Candidate, directory?: directory) }

    context 'when directory is true' do
      it { expect(subject.match(candidate)).to be :allow }
    end

    context 'when directory is false' do
      let(:directory) { false }

      it { expect(subject.match(candidate)).to be_nil }
    end
  end
end
