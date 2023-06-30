# frozen_string_literal: true

RSpec.describe PathList::Matchers::Ignore do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#match' do
    it 'returns :ignore' do
      expect(subject.match(instance_double(PathList::Candidate))).to be :ignore
    end
  end

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matchers::Ignore' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#polarity' do
    it { is_expected.to have_attributes(polarity: :ignore) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject], true)).to be subject
    end
  end

  describe '#compress_self' do
    it 'returns self' do
      expect(subject.compress_self).to be subject
    end
  end

  describe '#without_matcher' do
    it 'returns Blank if matcher is self' do
      expect(subject.without_matcher(subject)).to be PathList::Matchers::Blank
    end

    it 'returns self otherwise' do
      expect(subject.without_matcher(PathList::Matchers::Blank)).to be subject
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
