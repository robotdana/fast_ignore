# frozen_string_literal: true

RSpec.describe PathList::Matcher::Ignore do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#match' do
    it 'returns :ignore' do
      expect(subject.match(instance_double(PathList::Candidate))).to be :ignore
    end
  end

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matcher::Ignore' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#polarity' do
    it { is_expected.to have_attributes(polarity: :ignore) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matcher::Allow) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject], true)).to be subject
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
