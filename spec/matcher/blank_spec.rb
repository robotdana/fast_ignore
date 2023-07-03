# frozen_string_literal: true

RSpec.describe PathList::Matcher::Blank do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#match' do
    it 'returns nil' do
      expect(subject.match(instance_double(PathList::Candidate))).to be_nil
    end
  end

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matcher::Blank' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#polarity' do
    it { is_expected.to have_attributes(polarity: :mixed) }
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
