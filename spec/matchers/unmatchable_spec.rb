# frozen_string_literal: true

RSpec.describe FastIgnore::Matchers::Unmatchable do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value '#<FastIgnore::Matchers::Unmatchable>' }
  end

  describe '#dir_only?' do
    it { is_expected.not_to be_dir_only }
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
    it { is_expected.not_to be_squashable_with(::FastIgnore::Matchers::AllowAnyParent) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject])).to be subject
    end
  end

  describe '#append' do
    it 'returns nil' do
      expect(subject.append(instance_double(::FastIgnore::Patterns))).to be_nil
    end
  end

  describe '#match' do
    it 'returns nil' do
      expect(subject.match(instance_double(::FastIgnore::Candidate))).to be_nil
    end
  end
end
