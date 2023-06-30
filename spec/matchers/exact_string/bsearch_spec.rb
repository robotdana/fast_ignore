# frozen_string_literal: true

RSpec.describe PathList::Matchers::ExactString::Bsearch do
  subject { described_class.new(strings, polarity) }

  let(:polarity) { :allow }
  let(:strings) { ('/a'..'/z').to_a }

  it { is_expected.to be_frozen }

  describe '#match' do
    it { expect(subject.match(PathList::Candidate.new('/a', nil, nil))).to be :allow }
    it { expect(subject.match(PathList::Candidate.new('/A', nil, nil))).to be :allow }
    it { expect(subject.match(PathList::Candidate.new('/y', nil, nil))).to be :allow }
    it { expect(subject.match(PathList::Candidate.new('/Y', nil, nil))).to be :allow }
    it { expect(subject.match(PathList::Candidate.new('/', nil, nil))).to be_nil }
    it { expect(subject.match(PathList::Candidate.new('a', nil, nil))).to be_nil }
    it { expect(subject.match(PathList::Candidate.new('/a/', nil, nil))).to be_nil }

    context 'when polarity is :ignore' do
      let(:polarity) { :ignore }

      it { expect(subject.match(PathList::Candidate.new('/a', nil, nil))).to be :ignore }
      it { expect(subject.match(PathList::Candidate.new('/A', nil, nil))).to be :ignore }
      it { expect(subject.match(PathList::Candidate.new('/y', nil, nil))).to be :ignore }
      it { expect(subject.match(PathList::Candidate.new('/Y', nil, nil))).to be :ignore }
      it { expect(subject.match(PathList::Candidate.new('/', nil, nil))).to be_nil }
      it { expect(subject.match(PathList::Candidate.new('a', nil, nil))).to be_nil }
      it { expect(subject.match(PathList::Candidate.new('/a/', nil, nil))).to be_nil }
    end
  end

  describe '.build' do
    it 'calls .build on ExactString' do
      allow(PathList::Matchers::ExactString).to receive(:build).and_call_original
      expect(described_class.build(strings.reverse, polarity))
        .to be_like(described_class.new(strings, polarity))

      expect(PathList::Matchers::ExactString).to have_received(:build)
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matchers::ExactString::Bsearch.new([
          "/a",
          "/b",
          "/c",
          "/d",
          "/e",
          "/f",
          "/g",
          "/h",
          "/i",
          "/j",
          "/k",
          "/l",
          "/m",
          "/n",
          "/o",
          "/p",
          "/q",
          "/r",
          "/s",
          "/t",
          "/u",
          "/v",
          "/w",
          "/x",
          "/y",
          "/z"
        ], :allow)
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
    it { is_expected.to be_squashable_with(PathList::Matchers::ExactString.new('/other/path', :allow)) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::ExactString.new('/other/path', :ignore)) }
    it { is_expected.to be_squashable_with(described_class.new(('a'..'z').to_a, :allow)) }
    it { is_expected.not_to be_squashable_with(described_class.new(('a'..'z').to_a, :ignore)) }

    it do
      expect(subject).to be_squashable_with(
        PathList::Matchers::ExactString::Include.new(['a', 'b'], :allow)
      )
    end

    it do
      expect(subject).not_to be_squashable_with(
        PathList::Matchers::ExactString::Include.new(['a', 'b'], :ignore)
      )
    end
  end

  describe '#squash' do
    it 'squashes the list, building the right size' do
      other = PathList::Matchers::ExactString.new('/other/path', polarity)

      squashed = subject.squash([subject, other], true)

      expect(squashed).to be_like(
        described_class.new(
          [
            '/a', '/b', '/c', '/d', '/e', '/f', '/g', '/h', '/i', '/j', '/k', '/l', '/m', '/n', '/o',
            '/other/path', '/p', '/q', '/r', '/s', '/t', '/u', '/v', '/w', '/x', '/y', '/z'
          ], polarity
        )
      )
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
