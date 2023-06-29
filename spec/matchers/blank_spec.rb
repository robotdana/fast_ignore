# frozen_string_literal: true

RSpec.describe PathList::Matchers::Blank do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#match' do
    it 'returns nil' do
      expect(subject.match(instance_double(PathList::Candidate))).to be_nil
    end
  end

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matchers::Blank' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#polarity' do
    it { is_expected.to have_attributes(polarity: :mixed) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject])).to be subject
    end
  end

  describe '#compress_self' do
    it 'returns self' do
      expect(subject.compress_self).to be subject
    end
  end

  describe '#without_matcher' do
    it 'returns self' do
      expect(subject.without_matcher(subject)).to be subject
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
