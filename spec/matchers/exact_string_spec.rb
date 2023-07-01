# frozen_string_literal: true

RSpec.describe PathList::Matchers::ExactString do
  subject { described_class.new(string, polarity) }

  let(:polarity) { :allow }
  let(:string) { '/exact/path' }

  it { is_expected.to be_frozen }

  describe '#match' do
    it { expect(subject.match(PathList::Candidate.new('/exact/path', nil, nil))).to be :allow }
    it { expect(subject.match(PathList::Candidate.new('/Exact/Path', nil, nil))).to be :allow }
    it { expect(subject.match(PathList::Candidate.new('/exact', nil, nil))).to be_nil }
    it { expect(subject.match(PathList::Candidate.new('exact/path', nil, nil))).to be_nil }
    it { expect(subject.match(PathList::Candidate.new('/exact/path/', nil, nil))).to be_nil }

    context 'when polarity is :ignore' do
      let(:polarity) { :ignore }

      it { expect(subject.match(PathList::Candidate.new('/exact/path', nil, nil))).to be :ignore }
      it { expect(subject.match(PathList::Candidate.new('/Exact/Path', nil, nil))).to be :ignore }
      it { expect(subject.match(PathList::Candidate.new('/exact', nil, nil))).to be_nil }
      it { expect(subject.match(PathList::Candidate.new('exact/path', nil, nil))).to be_nil }
      it { expect(subject.match(PathList::Candidate.new('/exact/path/', nil, nil))).to be_nil }
    end
  end

  describe '.build' do
    it 'is ExactString when there is only one string' do
      expect(described_class.build(['/one/path'], polarity)).to be_like(
        described_class.new('/one/path', polarity)
      )
    end

    it 'is Blank when there is zero' do
      expect(described_class.build([], polarity))
        .to be_like(PathList::Matchers::Blank)
    end

    it 'is ExactString::Set when there is more' do
      expect(described_class.build(['/one/path', '/two/path', '/three/path'], polarity))
        .to be_like(
          described_class::Set.new(
            ['/one/path', '/two/path', '/three/path'], polarity
          )
        )
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matchers::ExactString.new("/exact/path", :allow)
      INSPECT
    end
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 1) }
  end

  describe '#polarity' do
    context 'when polarity is ignore' do
      let(:polarity) { :ignore }

      it { is_expected.to have_attributes(polarity: :ignore) }
    end

    context 'when polarity is allow' do
      let(:polarity) { :allow }

      it { is_expected.to have_attributes(polarity: :allow) }
    end
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(described_class.new('/other/path', :allow)) }
    it { is_expected.not_to be_squashable_with(described_class.new('/other/path', :ignore)) }
    it { is_expected.to be_squashable_with(described_class::Set.new(['a', 'b'], :allow)) }
    it { is_expected.not_to be_squashable_with(described_class::Set.new(['a', 'b'], :ignore)) }
  end

  describe '#squash' do
    it 'squashes the list, building the right size' do
      other = described_class.new('/other/path', polarity)

      squashed = subject.squash([subject, other], true)

      expect(squashed).to be_like(
        described_class::Set.new(
          ['/exact/path', '/other/path'], polarity
        )
      )
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
