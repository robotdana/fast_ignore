# frozen_string_literal: true

RSpec.describe PathList::Matchers::MatchIfDir do
  subject { described_class.build(matcher) }

  let(:polarity) { :allow }
  let(:matcher) do
    instance_double(
      PathList::Matchers::Base,
      'matcher',
      polarity: polarity,
      match: polarity,
      weight: 6,
      squashable_with?: false
    )
  end

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:directory) { true }
    let(:candidate) do
      instance_double(PathList::Candidate, 'candidate', directory?: directory)
    end

    context 'with a directory candidate' do
      context 'when allowing' do
        it do
          expect(subject.match(candidate)).to be :allow
          expect(matcher).to have_received(:match).with(candidate)
        end
      end

      context 'when not allowing' do
        let(:polarity) { :ignore }

        it do
          expect(subject.match(candidate)).to be :ignore
          expect(matcher).to have_received(:match).with(candidate)
        end
      end
    end

    context 'with a non-directory candidate' do
      let(:directory) { false }

      it do
        expect(subject.match(candidate)).to be_nil
        expect(matcher).not_to have_received(:match)
      end
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matchers::MatchIfDir.new(
          #{matcher.inspect}
        )
      INSPECT
    end
  end

  describe '#weight' do
    # weight of matcher * 0.2 + 1
    it { is_expected.to have_attributes(weight: 2.2) }
  end

  describe '#polarity' do
    context 'when polarity of matcher is ignore' do
      let(:polarity) { :ignore }

      it { is_expected.to have_attributes(polarity: :ignore) }
    end

    context 'when polarity of matcher is allow' do
      let(:polarity) { :allow }

      it { is_expected.to have_attributes(polarity: :allow) }
    end

    context 'when polarity of matcher is mixed' do
      let(:polarity) { :mixed }

      it { is_expected.to have_attributes(polarity: :mixed) }
    end
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }

    it 'is squashable with the other MatchIfDir matchers' do
      other = described_class.new(PathList::Matchers::Allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is squashable with AllowAnyDir' do
      expect(subject).to be_squashable_with(PathList::Matchers::AllowAnyDir)
    end
  end

  describe '#squash' do
    let(:polarity) { :ignore }

    it 'returns AllowAnyDir when AllowAnyDir is not last and preserve order is false' do
      expect(subject.squash([PathList::Matchers::AllowAnyDir, subject], false)).to be PathList::Matchers::AllowAnyDir
    end

    it 'returns self when self is last and preserve order is false' do
      expect(subject.squash([subject, PathList::Matchers::AllowAnyDir], false)).to be PathList::Matchers::AllowAnyDir
    end

    it 'returns new MatchIfDir matcher if self is not last' do
      expect(subject.squash([PathList::Matchers::AllowAnyDir, subject], true)).to be_like(
        described_class.new(
          PathList::Matchers::LastMatch::Two.new([
            PathList::Matchers::Allow,
            matcher
          ])
        )
      )
    end

    it "squashes the matchers even if AllowAnyDir isn't involved when preserve order is true" do
      other_matcher = instance_double(
        PathList::Matchers::Base, 'other_matcher', polarity: :mixed, weight: 3, squashable_with?: false
      )
      other_dir_matcher = described_class.new(other_matcher)

      expect(subject.squash([subject, other_dir_matcher], true)).to be_like(
        described_class.new(
          PathList::Matchers::LastMatch::Two.new([
            matcher,
            other_matcher
          ])
        )
      )
    end

    it "squashes the matchers even if AllowAnyDir isn't involved when preserve order is false" do
      other_matcher = instance_double(
        PathList::Matchers::Base, 'other_matcher', polarity: :mixed, weight: 3, squashable_with?: false
      )
      other_dir_matcher = described_class.new(other_matcher)

      expect(subject.squash([subject, other_dir_matcher], false)).to be_like(
        described_class.new(
          PathList::Matchers::Any::Two.new([
            other_matcher,
            matcher
          ])
        )
      )
    end

    it 'returns self when self is last and preserve order is true' do
      expect(subject.squash([subject, PathList::Matchers::AllowAnyDir], true)).to be PathList::Matchers::AllowAnyDir
    end
  end

  describe '#compress_self' do
    it 'passes to the matcher and returns self if the matcher is unchanged' do
      allow(matcher).to receive(:compress_self).and_return(matcher)
      expect(subject.compress_self).to be subject
      expect(matcher).to have_received(:compress_self)
    end

    it 'passes to the matcher and returns Blank if the matcher does' do
      allow(matcher).to receive(:compress_self).and_return(PathList::Matchers::Blank)
      expect(subject.compress_self).to be PathList::Matchers::Blank
      expect(matcher).to have_received(:compress_self)
    end

    it 'passes to the matcher and returns a new wrapper with the new matcher' do
      new_matcher = instance_double(PathList::Matchers::Base, 'new_matcher', polarity: polarity, weight: 1)
      allow(matcher).to receive(:compress_self).and_return(new_matcher)
      expect(subject.compress_self).to be_like(described_class.new(new_matcher))
      expect(matcher).to have_received(:compress_self)
    end
  end

  describe '#without_matcher' do
    it 'returns Blank if matcher is self' do
      expect(subject.without_matcher(subject)).to be PathList::Matchers::Blank
    end

    it 'passes to the matcher and returns self if the matcher is unchanged' do
      allow(matcher).to receive(:without_matcher).with(matcher).and_return(matcher)
      expect(subject.without_matcher(matcher)).to be subject
      expect(matcher).to have_received(:without_matcher).with(matcher)
    end

    it 'passes to the matcher and returns Blank if the matcher does' do
      allow(matcher).to receive(:without_matcher).with(matcher).and_return(PathList::Matchers::Blank)
      expect(subject.without_matcher(matcher)).to be PathList::Matchers::Blank
      expect(matcher).to have_received(:without_matcher).with(matcher)
    end

    it 'passes to the matcher and returns a new wrapper with the new matcher' do
      new_matcher = instance_double(PathList::Matchers::Base, 'new_matcher', polarity: polarity, weight: 1)
      allow(matcher).to receive(:without_matcher).with(matcher).and_return(new_matcher)
      expect(subject.without_matcher(matcher)).to be_like(described_class.new(new_matcher))
      expect(matcher).to have_received(:without_matcher).with(matcher)
    end
  end

  describe '#dir_matcher' do
    it 'returns the matcher after passing dir_matcher to it' do
      allow(matcher).to receive(:dir_matcher).and_return(matcher)
      expect(subject.dir_matcher).to be matcher
      expect(matcher).to have_received(:dir_matcher)
    end

    it 'passes to the matcher and returns Blank if the matcher does' do
      allow(matcher).to receive(:dir_matcher).and_return(PathList::Matchers::Blank)
      expect(subject.dir_matcher).to be PathList::Matchers::Blank
      expect(matcher).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'returns Blank' do
      allow(matcher).to receive(:file_matcher).and_return(matcher)
      expect(subject.file_matcher).to be PathList::Matchers::Blank
      expect(matcher).not_to have_received(:file_matcher)
    end
  end
end
