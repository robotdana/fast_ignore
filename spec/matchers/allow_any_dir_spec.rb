# frozen_string_literal: true

RSpec.describe PathList::Matchers::AllowAnyDir do
  subject { described_class }

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:directory) { instance_double(PathList::Candidate, 'directory', directory?: true) }
    let(:file) { instance_double(PathList::Candidate, 'file', directory?: false) }

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

    it do
      expect(subject).to be_squashable_with(
        PathList::Matchers::MatchIfDir.new(instance_double(PathList::Matchers::Base, 'other_matcher', weight: 1))
      )
    end

    it do
      expect(subject).not_to be_squashable_with(
        PathList::Matchers::MatchUnlessDir.new(instance_double(PathList::Matchers::Base, 'other_matcher', weight: 1))
      )
    end
  end

  describe '#squash' do
    let(:matcher) { instance_double(PathList::Matchers::Base, 'matcher', weight: 1, polarity: :ignore) }
    let(:dir_matcher) { PathList::Matchers::MatchIfDir.new(matcher) }

    it 'returns self when self is not last and preserve order is false' do
      expect(subject.squash([subject, dir_matcher], false)).to be subject
    end

    it 'returns self when self is last and preserve order is false' do
      expect(subject.squash([dir_matcher, subject], false)).to be subject
    end

    it 'returns MatchIfDir matcher if self is not last' do
      expect(subject.squash([subject, dir_matcher], true)).to be_like(
        PathList::Matchers::MatchIfDir.new(
          PathList::Matchers::LastMatch::Two.new([
            PathList::Matchers::Allow,
            matcher
          ])
        )
      )
    end

    it 'returns self when self is last and preserve order is true' do
      expect(subject.squash([dir_matcher, subject], true)).to be subject
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
