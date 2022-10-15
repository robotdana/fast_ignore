# frozen_string_literal: true

RSpec.describe FastIgnore::Matchers::Appendable do
  subject { described_class.new(label, matcher) }

  let(:matcher) { instance_double(::FastIgnore::Matchers::Base) }
  let(:candidate) { instance_double(::FastIgnore::Candidate) }
  let(:label) { :false_gitignore }
  let(:other_label) { :true_nonsense }
  let(:append_value) { instance_double(::FastIgnore::Patterns) }

  it { is_expected.to be_frozen }

  it 'inherits dir_only? when its true' do
    allow(matcher).to receive(:dir_only?).and_return(true)
    expect(subject).to be_dir_only
    expect(matcher).to have_received(:dir_only?)
  end

  it 'inherits dir_only? when its false' do
    allow(matcher).to receive(:dir_only?).and_return(false)
    expect(subject).not_to be_dir_only
    expect(matcher).to have_received(:dir_only?)
  end

  it 'inherits file_only? when its true' do
    allow(matcher).to receive(:file_only?).and_return(true)
    expect(subject).to be_file_only
    expect(matcher).to have_received(:file_only?)
  end

  it 'inherits file_only? when its false' do
    allow(matcher).to receive(:file_only?).and_return(false)
    expect(subject).not_to be_file_only
    expect(matcher).to have_received(:file_only?)
  end

  it 'inherits implicit? when its true' do
    allow(matcher).to receive(:implicit?).and_return(true)
    expect(subject).to be_implicit
    expect(matcher).to have_received(:implicit?)
  end

  it 'inherits implicit? when its false' do
    allow(matcher).to receive(:implicit?).and_return(false)
    expect(subject).not_to be_implicit
    expect(matcher).to have_received(:implicit?)
  end

  it { is_expected.not_to be_removable }

  it 'is squashable with something with the same label and the same kind of matcher' do
    other_child_matcher = instance_double(FastIgnore::Matchers::Base)
    allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(true)
    other_matcher = described_class.new(label, other_child_matcher)

    expect(subject).to be_squashable_with(other_matcher)
  end

  it 'is not squashable with something with a different label but the same kind of matcher' do
    other_child_matcher = instance_double(FastIgnore::Matchers::Base)
    allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(true)
    other_matcher = described_class.new(other_label, other_child_matcher)

    expect(subject).not_to be_squashable_with(other_matcher)
  end

  it 'is not squashable with something with the same label but a different kind of matcher' do
    other_child_matcher = instance_double(FastIgnore::Matchers::Base)
    allow(matcher).to receive(:squashable_with?).with(other_child_matcher).and_return(false)
    other_matcher = described_class.new(label, other_child_matcher)

    expect(subject).not_to be_squashable_with(other_matcher)
  end

  it 'is not squashable with something different' do
    expect(subject).not_to be_squashable_with(FastIgnore::Matchers::AllowAnyParent)
  end

  it 'returns a new matcher with squashed child matcher' do
    subject
    other = described_class.new(label, matcher)
    new_matcher = instance_double(FastIgnore::Matchers::Base)
    allow(matcher).to receive(:squash).with([matcher, matcher]).and_return(new_matcher)
    allow(described_class).to receive(:new).and_call_original

    subject.squash([subject, other])

    expect(described_class).to have_receive(:new).with(label, new_matcher)
  end

  context "when the append value label doesn't match" do
    before { allow(append_value).to receive(:label).and_return(other_label) }

    it "passes append to the matcher, returns nil when it's nil if the append value doesn't match" do
      allow(matcher).to receive(:append).with(append_value).and_return(nil)
      expect(subject.append(append_value)).to be_nil
      expect(matcher).to have_received(:append).with(append_value)
    end

    it "passes append to the matcher, returns a new matcher when it's changed" do
      new_matcher = instance_double(::FastIgnore::Matchers::Base)
      allow(matcher).to receive(:append).with(append_value).and_return(new_matcher)

      subject

      allow(described_class).to receive(:new).with(label, new_matcher).and_call_original
      appended_matcher = subject.append(append_value)
      expect(appended_matcher).to be_a(described_class)
      expect(appended_matcher).not_to be(subject)
      expect(matcher).to have_received(:append).with(append_value)
    end
  end

  context 'when the append value label does match' do
    before { allow(append_value).to receive(:label).and_return(label) }

    it "passes append to the matcher and reuses the existing matcher in the new matcher if it's nil" do
      subject

      allow(matcher).to receive(:append).with(append_value).and_return(nil)

      appended_matcher = instance_double(::FastIgnore::Matchers::Base)
      allow(append_value).to receive(:build_appended).and_return([appended_matcher])

      new_child_matcher = instance_double(::FastIgnore::Matchers::LastMatch)
      allow(::FastIgnore::Matchers::LastMatch).to receive(:new).with([
        matcher,
        appended_matcher
      ]).and_return(new_child_matcher)

      allow(described_class).to receive(:new).with(label, new_child_matcher).and_call_original

      appended_matcher = subject.append(append_value)
      expect(appended_matcher).to be_a(described_class)
      expect(appended_matcher).not_to be(subject)

      expect(matcher).to have_received(:append).with(append_value)
    end

    it "passes append to the matcher and uses the appended child matcher in the new matcher if it's present" do
      subject

      appended_child_matcher = instance_double(::FastIgnore::Matchers::Base)
      allow(matcher).to receive(:append).with(append_value).and_return(appended_child_matcher)

      appended_matcher = instance_double(::FastIgnore::Matchers::Base)
      allow(append_value).to receive(:build_appended).and_return([appended_matcher])

      new_child_matcher = instance_double(::FastIgnore::Matchers::LastMatch)
      allow(::FastIgnore::Matchers::LastMatch).to receive(:new).with([
        appended_child_matcher,
        appended_matcher
      ]).and_return(new_child_matcher)

      allow(described_class).to receive(:new).with(label, new_child_matcher).and_call_original

      appended_matcher = subject.append(append_value)
      expect(appended_matcher).to be_a(described_class)
      expect(appended_matcher).not_to be(subject)

      expect(matcher).to have_received(:append).with(append_value)
    end
  end

  it 'passes match to the matcher, returns the match value' do
    match_value = double
    allow(matcher).to receive(:match).with(candidate).and_return(match_value)
    expect(subject.match(candidate)).to be match_value
    expect(matcher).to have_received(:match).with(candidate)
  end

  # it 'has an inspect value' do
  #   expect(subject.inspect).to eq '#<FastIgnore::Matchers::AllowAnyParent>'
  # end
end
