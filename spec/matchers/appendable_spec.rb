# frozen_string_literal: true

RSpec.describe PathList::Matchers::Appendable do
  subject { described_class.new(label, matcher) }

  let(:matcher) do
    instance_double(
      ::PathList::Matchers::Base,
      removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
    )
  end
  let(:label) { :false_gitignore }
  let(:other_label) { :true_nonsense }
  let(:random_boolean) { [true, false].sample }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_default_inspect_value }
  end

  describe '#dir_only?' do
    it 'is matcher.dir_only? when true' do
      allow(matcher).to receive(:dir_only?).and_return(true)
      expect(subject).to be_dir_only
      expect(matcher).to have_received(:dir_only?)
    end

    it 'is matcher.dir_only? when false' do
      allow(matcher).to receive(:dir_only?).and_return(false)
      expect(subject).not_to be_dir_only
      expect(matcher).to have_received(:dir_only?)
    end

    it 'is matcher.dir_only? when random' do
      allow(matcher).to receive(:dir_only?).and_return(random_boolean)
      expect(subject.dir_only?).to be random_boolean
      expect(matcher).to have_received(:dir_only?)
    end
  end

  describe '#file_only?' do
    it 'is matcher.file_only? when true' do
      allow(matcher).to receive(:file_only?).and_return(true)
      expect(subject).to be_file_only
      expect(matcher).to have_received(:file_only?)
    end

    it 'is matcher.file_only? when false' do
      allow(matcher).to receive(:file_only?).and_return(false)
      expect(subject).not_to be_file_only
      expect(matcher).to have_received(:file_only?)
    end

    it 'is matcher.file_only? when random' do
      allow(matcher).to receive(:file_only?).and_return(random_boolean)
      expect(subject.file_only?).to be random_boolean
      expect(matcher).to have_received(:file_only?)
    end
  end

  describe '#implicit?' do
    it 'is matcher.implicit? when true' do
      allow(matcher).to receive(:implicit?).and_return(true)
      expect(subject).to be_implicit
      expect(matcher).to have_received(:implicit?)
    end

    it 'is matcher.implicit? when false' do
      allow(matcher).to receive(:implicit?).and_return(false)
      expect(subject).not_to be_implicit
      expect(matcher).to have_received(:implicit?)
    end

    it 'is matcher.implicit? when random' do
      allow(matcher).to receive(:implicit?).and_return(random_boolean)
      expect(subject.implicit?).to be random_boolean
      expect(matcher).to have_received(:implicit?)
    end
  end

  describe '#removable?' do
    it { is_expected.not_to be_removable }
  end

  describe '#weight' do
    let(:random_int) { rand(10) }

    it 'is matcher.weight when 0' do
      allow(matcher).to receive(:weight).and_return(0)
      expect(subject.weight).to be 0
      expect(matcher).to have_received(:weight)
    end

    it 'is matcher.weight when 1' do
      allow(matcher).to receive(:weight).and_return(1)
      expect(subject.weight).to be 1
      expect(matcher).to have_received(:weight)
    end

    it 'is matcher.weight when random' do
      allow(matcher).to receive(:weight).and_return(random_int)
      expect(subject.weight).to be random_int
      expect(matcher).to have_received(:weight)
    end
  end

  describe '#squashable_with?' do
    it 'is squashable with something with the same label and the same kind of matcher' do
      other_child_matcher = instance_double(
        ::PathList::Matchers::Base,
        removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
      )
      allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(true)
      other_matcher = described_class.new(label, other_child_matcher)

      expect(subject).to be_squashable_with(other_matcher)
    end

    it 'is not squashable with something with a different label but the same kind of matcher' do
      other_child_matcher = instance_double(
        ::PathList::Matchers::Base,
        removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
      )
      allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(true)
      other_matcher = described_class.new(other_label, other_child_matcher)

      expect(subject).not_to be_squashable_with(other_matcher)
    end

    it 'is not squashable with something with the same label but a different kind of matcher' do
      other_child_matcher = instance_double(
        ::PathList::Matchers::Base,
        removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
      )
      allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(false)
      other_matcher = described_class.new(label, other_child_matcher)

      expect(subject).not_to be_squashable_with(other_matcher)
    end

    it 'is not squashable with something different' do
      expect(subject).not_to be_squashable_with(PathList::Matchers::AllowAnyParent)
    end
  end

  describe '#squash' do
    it 'returns a new matcher with squashed child matcher' do
      subject
      other = described_class.new(label, matcher)
      new_matcher = instance_double(
        ::PathList::Matchers::Base,
        removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
      )
      allow(matcher).to receive(:squash).with([matcher, matcher]).and_return(new_matcher)
      allow(described_class).to receive(:new).and_call_original

      subject.squash([subject, other])

      expect(described_class).to have_received(:new).with(label, new_matcher)
    end
  end

  describe '#append' do
    let(:patterns) { instance_double(::PathList::Patterns) }

    context "when the append value label doesn't match" do
      before { allow(patterns).to receive(:label).and_return(other_label) }

      it "passes append to the matcher, returns nil when it's nil if the append value doesn't match" do
        allow(matcher).to receive(:append).with(patterns).and_return(nil)
        expect(subject.append(patterns)).to be_nil
        expect(matcher).to have_received(:append).with(patterns)
      end

      it "passes append to the matcher, returns a new matcher when it's changed" do
        new_matcher = instance_double(
          ::PathList::Matchers::Base,
          removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
        )
        allow(matcher).to receive(:append).with(patterns).and_return(new_matcher)

        subject

        allow(described_class).to receive(:new).with(label, new_matcher).and_call_original
        appended_matcher = subject.append(patterns)
        expect(appended_matcher).to be_a(described_class)
        expect(appended_matcher).not_to be(subject)
        expect(matcher).to have_received(:append).with(patterns)
      end
    end

    context 'when the append value label does match' do
      before { allow(patterns).to receive(:label).and_return(label) }

      it "passes append to the matcher and reuses the existing matcher in the new matcher if it's nil" do
        subject

        allow(matcher).to receive(:append).with(patterns).and_return(nil)

        appended_matcher = instance_double(
          ::PathList::Matchers::Base,
          removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
        )
        allow(patterns).to receive(:build_appended).and_return([appended_matcher])

        new_child_matcher = instance_double(::PathList::Matchers::LastMatch)
        allow(::PathList::Matchers::LastMatch).to receive(:new).with([
          matcher,
          appended_matcher
        ]).and_return(new_child_matcher)

        allow(described_class).to receive(:new).with(label, new_child_matcher).and_call_original

        appended_matcher = subject.append(patterns)
        expect(appended_matcher).to be_a(described_class)
        expect(appended_matcher).not_to be(subject)

        expect(matcher).to have_received(:append).with(patterns)
      end

      it "passes append to the matcher and uses the appended child matcher in the new matcher if it's present" do
        subject

        appended_child_matcher = instance_double(
          ::PathList::Matchers::Base,
          removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
        )
        allow(matcher).to receive(:append).with(patterns).and_return(appended_child_matcher)

        appended_matcher = instance_double(
          ::PathList::Matchers::Base,
          removable?: false, implicit?: false, squashable_with?: false, polarity: :mixed, weight: 1
        )
        allow(patterns).to receive(:build_appended).and_return([appended_matcher])

        new_child_matcher = instance_double(::PathList::Matchers::LastMatch)
        allow(::PathList::Matchers::LastMatch).to receive(:new).with([
          appended_child_matcher,
          appended_matcher
        ]).and_return(new_child_matcher)

        allow(described_class).to receive(:new).with(label, new_child_matcher).and_call_original

        appended_matcher = subject.append(patterns)
        expect(appended_matcher).to be_a(described_class)
        expect(appended_matcher).not_to be(subject)

        expect(matcher).to have_received(:append).with(patterns)
      end
    end
  end

  describe '#match' do
    let(:candidate) { instance_double(::PathList::Candidate) }
    let(:match_result) { [:allow, :ignore, nil].sample }

    it 'is matcher.match when :allow' do
      allow(matcher).to receive(:match).with(candidate).and_return(:allow)
      expect(subject.match(candidate)).to be :allow
      expect(matcher).to have_received(:match)
    end

    it 'is matcher.match when :ignore' do
      allow(matcher).to receive(:match).with(candidate).and_return(:ignore)
      expect(subject.match(candidate)).to be :ignore
      expect(matcher).to have_received(:match)
    end

    it 'is matcher.match when nil' do
      allow(matcher).to receive(:match).with(candidate).and_return(nil)
      expect(subject.match(candidate)).to be_nil
      expect(matcher).to have_received(:match)
    end

    it 'is matcher.match when random' do
      allow(matcher).to receive(:match).with(candidate).and_return(match_result)
      expect(subject.match(candidate)).to be match_result
      expect(matcher).to have_received(:match)
    end
  end
end
