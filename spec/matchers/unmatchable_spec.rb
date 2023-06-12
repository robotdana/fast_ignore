# frozen_string_literal: true

RSpec.describe PathList::Matchers::Unmatchable do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value '#<PathList::Matchers::Unmatchable>' }
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
    it { is_expected.not_to be_squashable_with(::PathList::Matchers::Allow) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject])).to be subject
    end
  end

  describe '#match' do
    it 'returns nil' do
      expect(subject.match(instance_double(::PathList::Candidate))).to be_nil
    end
  end

  describe '#eql?' do
    it { is_expected.to eq(subject) }
    it { is_expected.not_to eq(::PathList::Matchers::Allow) }
  end
end
