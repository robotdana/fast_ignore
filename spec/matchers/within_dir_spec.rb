# frozen_string_literal: true

RSpec.describe PathList::Matchers::WithinDir do
  subject { described_class.new(dir, matcher) }

  let(:matcher) do
    instance_double(::PathList::Matchers::Base, squashable_with?: false, weight: 1)
  end
  let(:dir) { '/a_dir' }
  let(:other_dir) { '/tmp' }
  let(:random_boolean) { [true, false].sample }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it 'is nicely formatted' do
      expect(subject.inspect).to eq <<~INSPECT.chomp
        #<PathList::Matchers::WithinDir @dir="/a_dir" @matcher=(
          #{matcher.inspect}
        )>
      INSPECT
    end
  end

  describe '#weight' do
    let(:random_int) { rand(10) }

    it 'is matcher.weight / 2 + 1 when matcher.weight = 0' do
      allow(matcher).to receive(:weight).and_return(0)
      expect(subject.weight).to eq 1
      expect(matcher).to have_received(:weight)
    end

    it 'is matcher.weight / 2 + 1 when matcher.weight = 1' do
      allow(matcher).to receive(:weight).and_return(1)
      expect(subject.weight).to eq 1.5
      expect(matcher).to have_received(:weight)
    end

    it 'is matcher.weight / 2 + 1 when matcher.weight random' do
      allow(matcher).to receive(:weight).and_return(random_int)
      expect(subject.weight).to eq (random_int / 2.0) + 1
      expect(matcher).to have_received(:weight)
    end
  end

  describe '#squashable_with?' do
    it 'is squashable with something with the same dir and the same kind of matcher' do
      other_child_matcher = instance_double(PathList::Matchers::Base, weight: 0)
      allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(true)
      other_matcher = described_class.new(dir, other_child_matcher)

      expect(subject).to be_squashable_with(other_matcher)
    end

    it 'is not squashable with something with a different dir but the same kind of matcher' do
      other_child_matcher = instance_double(PathList::Matchers::Base, weight: 0)
      allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(true)
      other_matcher = described_class.new(other_dir, other_child_matcher)

      expect(subject).not_to be_squashable_with(other_matcher)
    end

    it 'is squashable with something with the same dir but a different kind of matcher' do
      other_child_matcher = instance_double(PathList::Matchers::Base, weight: 0)
      allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(false)
      other_matcher = described_class.new(dir, other_child_matcher)

      expect(subject).to be_squashable_with(other_matcher)
    end

    it 'is not squashable with something different' do
      expect(subject).not_to be_squashable_with(PathList::Matchers::Allow)
    end
  end

  describe '#squash' do
    it 'returns a new matcher with squashed child matcher' do
      subject

      other_matcher = instance_double(
        PathList::Matchers::Base,
        squashable_with?: false, weight: 1
      )
      other = described_class.new(dir, other_matcher)

      new_matcher = instance_double(
        PathList::Matchers::Any,
        squashable_with?: false, weight: 1
      )
      allow(PathList::Matchers::Any).to receive(:new).with([matcher, other_matcher]).and_return(new_matcher)
      allow(described_class).to receive(:new).and_call_original

      subject.squash([subject, other])

      expect(described_class).to have_received(:new).with(dir, new_matcher)
    end
  end

  describe '#match' do
    let(:candidate) { instance_double(::PathList::Candidate) }
    let(:inner_candidate) { instance_double(::PathList::Candidate) }

    let(:match_result) { [:allow, :ignore, nil].sample }

    context 'when candidate is within dir' do
      before do
        allow(candidate).to receive(:with_path_relative_to)
          .with(dir).and_yield(inner_candidate)
      end

      it 'is matcher.match when :allow' do
        allow(matcher).to receive(:match).with(inner_candidate).and_return(:allow)
        expect(subject.match(candidate)).to be :allow
        expect(matcher).to have_received(:match)
      end

      it 'is matcher.match when :ignore' do
        allow(matcher).to receive(:match).with(inner_candidate).and_return(:ignore)
        expect(subject.match(candidate)).to be :ignore
        expect(matcher).to have_received(:match)
      end

      it 'is matcher.match when nil' do
        allow(matcher).to receive(:match).with(inner_candidate).and_return(nil)
        expect(subject.match(candidate)).to be_nil
        expect(matcher).to have_received(:match)
      end

      it 'is matcher.match when random' do
        allow(matcher).to receive(:match).with(inner_candidate).and_return(match_result)
        expect(subject.match(candidate)).to be match_result
        expect(matcher).to have_received(:match)
      end
    end

    context 'when candidate is not within dir' do
      before do
        allow(candidate).to receive(:with_path_relative_to)
          .with(dir).and_return(nil)
      end

      it 'is nil' do
        expect(subject.match(candidate)).to be_nil
      end
    end
  end
end
