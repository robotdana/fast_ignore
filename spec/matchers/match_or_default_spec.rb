# frozen_string_literal: true

RSpec.describe FastIgnore::Matchers::MatchOrDefault do
  subject { described_class.new(matcher, default) }

  let(:matcher) { instance_double(::FastIgnore::Matchers::Base) }
  let(:candidate) { instance_double(::FastIgnore::Candidate) }
  let(:default) { [:allow, :ignore].sample }
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

  it 'inherits removable? when its true' do
    allow(matcher).to receive(:removable?).and_return(true)
    expect(subject).to be_removable
    expect(matcher).to have_received(:removable?)
  end

  it 'inherits removable? when its false' do
    allow(matcher).to receive(:removable?).and_return(false)
    expect(subject).not_to be_removable
    expect(matcher).to have_received(:removable?)
  end

  it { is_expected.to be_squashable_with(subject) }
  it { is_expected.not_to be_squashable_with(described_class.new(matcher, default)) }

  it 'returns itself when squashing with itself' do
    expect(subject.squash([subject, subject])).to be subject
  end

  it "passes append to the matcher, returns nil when it's nil" do
    allow(matcher).to receive(:append).with(append_value).and_return(nil)
    expect(subject.append(append_value)).to be_nil
    expect(matcher).to have_received(:append).with(append_value)
  end

  it "passes append to the matcher, returns a new matcher when it's changed" do
    new_matcher = instance_double(::FastIgnore::Matchers::Base)
    allow(matcher).to receive(:append).with(append_value).and_return(new_matcher)

    subject

    allow(described_class).to receive(:new).with(new_matcher, default).and_call_original
    appended_matcher = subject.append(append_value)
    expect(appended_matcher).to be_a(described_class)
    expect(appended_matcher).not_to be(subject)
    expect(matcher).to have_received(:append).with(append_value)
  end

  it "passes match to the matcher, returns default when it's nil" do
    allow(matcher).to receive(:match).with(candidate).and_return(nil)
    expect(subject.match(candidate)).to be default
    expect(matcher).to have_received(:match).with(candidate)
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
