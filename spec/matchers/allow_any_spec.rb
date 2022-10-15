# frozen_string_literal: true

RSpec.describe FastIgnore::Matchers::AllowAny do
  subject { described_class }

  it { is_expected.not_to be_dir_only }
  it { is_expected.not_to be_file_only }
  it { is_expected.to be_implicit }
  it { is_expected.to be_squashable_with(subject) }
  it { is_expected.not_to be_squashable_with(::FastIgnore::Matchers::AllowAnyParent) }
  it { is_expected.not_to be_removable }
  it { is_expected.to be_frozen }

  it 'returns self when squashing' do
    expect(subject.squash([subject, subject])).to be subject
  end

  it 'returns nil when appending' do
    expect(subject.append(instance_double(::FastIgnore::Patterns))).to be_nil
  end

  it 'returns :allows when matching' do
    expect(subject.match(instance_double(::FastIgnore::Candidate))).to be :allow
  end

  it 'has an inspect value' do
    expect(subject.inspect).to eq '#<FastIgnore::Matchers::AllowAny>'
  end
end
