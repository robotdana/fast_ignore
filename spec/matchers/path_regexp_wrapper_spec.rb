# frozen_string_literal: true

RSpec.describe PathList::Matchers::PathRegexpWrapper do
  subject { described_class.build(builder, matcher) }

  let(:polarity) { :allow }
  let(:matcher) do
    instance_double(
      PathList::Matchers::Base,
      'matcher',
      polarity: polarity,
      match: polarity,
      weight: 7
    )
  end

  let(:builder) { PathList::RegexpBuilder.new({ 'a' => nil }) }

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:path) { 'my/file.rb' }
    let(:builder) { PathList::RegexpBuilder.new(['file.rb']) }

    let(:candidate) do
      instance_double(PathList::Candidate, 'candidate', full_path: "/#{path}", full_path_downcase: "/#{path.downcase}")
    end

    context 'with a matching rule' do
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

    context 'with a non-matching rule' do
      let(:path) { 'my/file.sh/' }

      it do
        expect(subject.match(candidate)).to be_nil
        expect(matcher).not_to have_received(:match)
      end
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matchers::PathRegexpWrapper.new(
          /a/,
          #{matcher.inspect}
        )
      INSPECT
    end
  end

  describe '#weight' do
    # weight of matcher plus weight of regexp
    it { is_expected.to have_attributes(weight: 9.75) }
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

    it 'is squashable with the other matchers with the same regexp' do
      other = described_class.build(PathList::RegexpBuilder.new({ 'a' => nil }), PathList::Matchers::Allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with the other matchers with different regexp' do
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), PathList::Matchers::Allow)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the matchers together' do
      subject
      other_matcher = instance_double(
        PathList::Matchers::Base, 'other_matcher', weight: 2, polarity: polarity, squashable_with?: false
      )
      other = described_class.build(PathList::RegexpBuilder.new({ 'a' => nil }), other_matcher)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other], false)

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      squashed_matcher = PathList::Matchers::Any::Two.new([
        other_matcher,
        matcher
      ])

      expect(squashed).to be_like(
        described_class.build(
          PathList::RegexpBuilder.new({ 'a' => nil }),
          squashed_matcher
        )
      )
      expect(squashed).to be_like(described_class.new(/a/, squashed_matcher))
    end
  end

  describe '#compress_self' do
    context 'with an uncompressed regexp' do
      let(:builder) { PathList::RegexpBuilder.new({ 'a' => { any: { end_anchor: nil } } }) }

      it 'compresses the regexp but only once' do
        allow(matcher).to receive(:compress_self).and_return(matcher)

        new_matcher = subject.compress_self
        expect(new_matcher).to be_like(
          described_class.build(PathList::RegexpBuilder.new({ 'a' => nil }), matcher)
        )
        expect(new_matcher).not_to be subject
        expect(new_matcher.compress_self).to be new_matcher
        expect(matcher).to have_received(:compress_self).at_least(:once)
      end

      it 'also compresses matcher' do
        other_matcher = instance_double(PathList::Matchers::Base, 'other_matcher', polarity: polarity, weight: 1)
        allow(matcher).to receive(:compress_self).and_return(other_matcher)
        allow(other_matcher).to receive(:compress_self).and_return(other_matcher).at_least(:once)

        new_matcher = subject.compress_self
        expect(new_matcher).to be_like(
          described_class.build(PathList::RegexpBuilder.new({ 'a' => nil }), other_matcher)
        )
        expect(matcher).to have_received(:compress_self)
        expect(new_matcher).not_to be subject
        expect(new_matcher.compress_self).to be new_matcher
      end
    end

    context 'with a compressed regexp' do
      let(:builder) { PathList::RegexpBuilder.new({ 'a' => nil }).compress }

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
        expect(subject.compress_self).to be_like(
          described_class.new(
            /a/,
            new_matcher,
            PathList::RegexpBuilder.new({ 'a' => nil })
          )
        )
        expect(matcher).to have_received(:compress_self)
      end
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
      expect(subject.without_matcher(matcher)).to be_like(
        described_class.new(
          /a/,
          new_matcher,
          PathList::RegexpBuilder.new({ 'a' => nil })
        )
      )
      expect(matcher).to have_received(:without_matcher).with(matcher)
    end
  end

  describe '#dir_matcher' do
    it 'passes to the matcher and returns self if the matcher is unchanged' do
      allow(matcher).to receive(:dir_matcher).and_return(matcher)
      expect(subject.dir_matcher).to be subject
      expect(matcher).to have_received(:dir_matcher)
    end

    it 'passes to the matcher and returns Blank if the matcher does' do
      allow(matcher).to receive(:dir_matcher).and_return(PathList::Matchers::Blank)
      expect(subject.dir_matcher).to be PathList::Matchers::Blank
      expect(matcher).to have_received(:dir_matcher)
    end

    it 'passes to the matcher and returns a new wrapper with the new matcher' do
      new_matcher = instance_double(PathList::Matchers::Base, 'new_matcher', polarity: polarity, weight: 1)
      allow(matcher).to receive(:dir_matcher).and_return(new_matcher)
      expect(subject.dir_matcher).to be_like(
        described_class.new(
          /a/,
          new_matcher,
          PathList::RegexpBuilder.new({ 'a' => nil })
        )
      )
      expect(matcher).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'passes to the matcher and returns self if the matcher is unchanged' do
      allow(matcher).to receive(:file_matcher).and_return(matcher)
      expect(subject.file_matcher).to be subject
      expect(matcher).to have_received(:file_matcher)
    end

    it 'passes to the matcher and returns Blank if the matcher does' do
      allow(matcher).to receive(:file_matcher).and_return(PathList::Matchers::Blank)
      expect(subject.file_matcher).to be PathList::Matchers::Blank
      expect(matcher).to have_received(:file_matcher)
    end

    it 'passes to the matcher and returns a new wrapper with the new matcher' do
      new_matcher = instance_double(PathList::Matchers::Base, 'new_matcher', polarity: polarity, weight: 1)
      allow(matcher).to receive(:file_matcher).and_return(new_matcher)
      expect(subject.file_matcher).to be_like(
        described_class.new(
          /a/,
          new_matcher,
          PathList::RegexpBuilder.new({ 'a' => nil })
        )
      )
      expect(matcher).to have_received(:file_matcher)
    end
  end
end
