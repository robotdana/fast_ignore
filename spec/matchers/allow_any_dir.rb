# frozen_string_literal: true

RSpec.describe PathList::Matchers::AllowAnyDir do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:directory) { instance_double(PathList::Candidate, directory?: true) }
    let(:file) { instance_double(PathList::Candidate, directory?: false) }

    it 'returns :allow for directories' do
      expect(subject.match(directory)).to be :allow
    end

    it 'returns nil otherwise' do
      expect(subject.match(file)).to be_nil
    end
  end

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matchers::AllowAnyDir' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#polarity' do
    it { is_expected.to have_attributes(polarity: :allow) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.to be_squashable_with(instance_double(PathList::Matchers::MatchIfDir, polarity: :allow)) }
    it { is_expected.not_to be_squashable_with(instance_double(PathList::Matchers::MatchIfDir, polarity: :ignore)) }
    it { is_expected.not_to be_squashable_with(instance_double(PathList::Matchers::MatchUnlessDir, polarity: :allow)) }
  end

  describe '#squash' do
    let(:dir_matcher) { instance_double(PathList::Matchers::MatchIfDir) }

    it 'returns self when self is first' do
      expect(subject.squash([subject, dir_matcher])).to be subject
    end

    it 'returns self when self is not first' do
      expect(subject.squash([dir_matcher, subject])).to be subject
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
    it 'returns Allow' do
      expect(subject.dir_matcher).to be PathList::Matchers::Allow
    end
  end

  describe '#file_matcher' do
    it 'returns Blank' do
      expect(subject.file_matcher).to be PathList::Matchers::Blank
    end
  end
end
