# frozen_string_literal: true

RSpec.describe PathList::Matchers::MatchOrDefault do
  subject { described_class.new(matcher, default) }

  let(:matcher) { instance_double(::PathList::Matchers::Base) }
  let(:default) { [:allow, :ignore].sample }
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
    it 'is matcher.removable? when true' do
      allow(matcher).to receive(:removable?).and_return(true)
      expect(subject).to be_removable
      expect(matcher).to have_received(:removable?)
    end

    it 'is matcher.removable? when false' do
      allow(matcher).to receive(:removable?).and_return(false)
      expect(subject).not_to be_removable
      expect(matcher).to have_received(:removable?)
    end

    it 'is matcher.removable? when random' do
      allow(matcher).to receive(:removable?).and_return(random_boolean)
      expect(subject.removable?).to be random_boolean
      expect(matcher).to have_received(:removable?)
    end
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
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(described_class.new(matcher, default)) }
  end

  describe '#squash' do
    it 'returns self' do
      expect(subject.squash([subject, subject])).to be subject
    end
  end

  describe '#append' do
    let(:patterns) { instance_double(::PathList::Patterns) }

    it 'is matcher.append when nil' do
      allow(matcher).to receive(:append).with(patterns).and_return(nil)
      expect(subject.append(patterns)).to be_nil
      expect(matcher).to have_received(:append).with(patterns)
    end

    it 'returns a new matcher when matcher.append is changed' do
      new_matcher = instance_double(::PathList::Matchers::Base)
      allow(matcher).to receive(:append).with(patterns).and_return(new_matcher)

      subject

      allow(described_class).to receive(:new).with(new_matcher, default).and_call_original
      appended_matcher = subject.append(patterns)
      expect(appended_matcher).to be_a(described_class)
      expect(appended_matcher).not_to be(subject)
      expect(matcher).to have_received(:append).with(patterns)
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

    it 'is default matcher.match is nil' do
      allow(matcher).to receive(:match).with(candidate).and_return(nil)
      expect(subject.match(candidate)).to be default
      expect(matcher).to have_received(:match)
    end

    it 'is matcher.match || default when random' do
      allow(matcher).to receive(:match).with(candidate).and_return(match_result)
      expect(subject.match(candidate)).to be(match_result || default)
      expect(matcher).to have_received(:match)
    end
  end
end
