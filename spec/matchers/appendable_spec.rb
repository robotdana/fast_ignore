# frozen_string_literal: true

RSpec.describe PathList::Matchers::Appendable do
  subject { described_class.new(label, default, implicit_matcher, explicit_matcher, original_pattern) }

  let(:default) { PathList::Matchers::Unmatchable }
  let(:original_pattern) { instance_double(::PathList::Patterns) }
  let(:implicit_matcher) do
    instance_double(
      ::PathList::Matchers::Base,
      squashable_with?: false, polarity: :mixed, weight: 1
    )
  end
  let(:explicit_matcher) do
    instance_double(
      ::PathList::Matchers::Base,
      squashable_with?: false, polarity: :mixed, weight: 1
    )
  end
  let(:label) { :false_gitignore }
  let(:random_boolean) { [true, false].sample }
  let(:candidate) { instance_double(::PathList::Candidate) }

  it { is_expected.not_to be_frozen }

  describe '#inspect' do
    it 'is nicely formatted' do
      expect(subject.inspect).to eq <<~INSPECT.chomp
        #<PathList::Matchers::Appendable @label=:false_gitignore @matcher=(
          #<PathList::Matchers::LastMatch @matchers=[
            #{implicit_matcher.inspect},
            #{explicit_matcher.inspect}
          ]>
        )>
      INSPECT
    end
  end

  describe '#weight' do
    let(:random_int) { rand(10) }

    it 'is matcher.weight when 0' do
      allow(explicit_matcher).to receive(:weight).and_return(0)
      allow(implicit_matcher).to receive(:weight).and_return(0)
      expect(subject.weight).to eq 1.0
      expect(explicit_matcher).to have_received(:weight).at_least(:once)
      expect(implicit_matcher).to have_received(:weight).at_least(:once)
    end

    it 'is matcher.weight when 1' do
      allow(explicit_matcher).to receive(:weight).and_return(1)
      allow(implicit_matcher).to receive(:weight).and_return(1)
      expect(subject.weight).to eq 2
      expect(explicit_matcher).to have_received(:weight).at_least(:once)
      expect(implicit_matcher).to have_received(:weight).at_least(:once)
    end

    it 'is matcher.weight when random' do
      allow(explicit_matcher).to receive(:weight).and_return(random_int)
      allow(implicit_matcher).to receive(:weight).and_return(0)
      expect(subject.weight).to eq (random_int / 2) + 1
      expect(explicit_matcher).to have_received(:weight).at_least(:once)
      expect(implicit_matcher).to have_received(:weight).at_least(:once)
    end
  end

  describe '#squashable_with?' do
    it 'is not squashable' do
      other_matcher = described_class.new(label, default, implicit_matcher, explicit_matcher, original_pattern)

      expect(subject).not_to be_squashable_with(other_matcher)
    end
  end

  describe '#append' do
    let(:patterns) { instance_double(::PathList::Patterns, label: label, content?: true, 'allow=': nil) }

    it 'appends the patterns to the matcher' do
      subject

      appended_implicit_matcher = instance_double(
        ::PathList::Matchers::Base,
        squashable_with?: false, polarity: :mixed, weight: 1
      )
      appended_explicit_matcher = instance_double(
        ::PathList::Matchers::Base,
        squashable_with?: false, polarity: :mixed, weight: 1
      )
      allow(patterns).to receive(:build_matchers).and_return([appended_implicit_matcher, appended_explicit_matcher])

      new_explicit_matcher = instance_double(
        ::PathList::Matchers::LastMatch,
        squashable_with?: false, polarity: :mixed, weight: 1
      )

      new_implicit_matcher = instance_double(
        ::PathList::Matchers::Any,
        squashable_with?: false, polarity: :mixed, weight: 1
      )

      new_appended_matcher = instance_double(::PathList::Matchers::LastMatch, match: nil)

      allow(::PathList::Matchers::LastMatch).to receive(:new).with([
        explicit_matcher,
        appended_explicit_matcher
      ]).and_return(new_explicit_matcher)
      allow(::PathList::Matchers::Any).to receive(:new).with([
        implicit_matcher,
        appended_implicit_matcher
      ]).and_return(new_implicit_matcher)

      allow(::PathList::Matchers::LastMatch).to receive(:new).with([
        new_implicit_matcher, new_explicit_matcher
      ]).and_return(new_appended_matcher)

      subject.append(patterns)
      expect(subject.match(candidate)).to be_nil
      expect(new_appended_matcher).to have_received(:match).with(candidate)
    end
  end

  describe '#match' do
    let(:candidate) { instance_double(::PathList::Candidate) }

    it 'is explicit_matcher.match when :allow' do
      allow(explicit_matcher).to receive(:match).with(candidate).and_return(:allow)
      allow(implicit_matcher).to receive(:match)
      expect(subject.match(candidate)).to be :allow
      expect(explicit_matcher).to have_received(:match)
      expect(implicit_matcher).not_to have_received(:match)
    end

    it 'is explicit_matcher.match when :ignore' do
      allow(explicit_matcher).to receive(:match).with(candidate).and_return(:ignore)
      allow(implicit_matcher).to receive(:match)
      expect(subject.match(candidate)).to be :ignore
      expect(explicit_matcher).to have_received(:match)
      expect(implicit_matcher).not_to have_received(:match)
    end

    it 'falls through implicit_matcher.match when explicit_matcher.match is nil' do
      allow(explicit_matcher).to receive(:match).with(candidate).and_return(nil)
      allow(implicit_matcher).to receive(:match).with(candidate).and_return(nil)
      expect(subject.match(candidate)).to be_nil
      expect(explicit_matcher).to have_received(:match)
      expect(implicit_matcher).to have_received(:match)
    end

    it 'falls back to implicit_matcher.match when explicit_matcher.match is nil' do
      allow(explicit_matcher).to receive(:match).with(candidate).and_return(nil)
      allow(implicit_matcher).to receive(:match).with(candidate).and_return(:allow)
      expect(subject.match(candidate)).to be :allow
      expect(explicit_matcher).to have_received(:match)
      expect(implicit_matcher).to have_received(:match)
    end
  end
end
