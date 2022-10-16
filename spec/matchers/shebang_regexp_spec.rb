# frozen_string_literal: true

RSpec.describe FastIgnore::Matchers::ShebangRegexp do
  subject { described_class.new(rule, allow_value) }

  let(:rule) { /a/ }
  let(:allow_value) { true }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value '#<FastIgnore::Matchers::ShebangRegexp :allow /a/>' }
  end

  describe '#dir_only?' do
    it { is_expected.not_to be_dir_only }
  end

  describe '#file_only?' do
    it { is_expected.to be_file_only }
  end

  describe '#implicit?' do
    it { is_expected.not_to be_implicit }
  end

  describe '#removable?' do
    it { is_expected.not_to be_removable }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 2) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(::FastIgnore::Matchers::AllowAnyParent) }

    it 'is squashable with the same return value' do
      other = described_class.new(/b/, allow_value)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different return value' do
      other = described_class.new(/b/, !allow_value)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.new(/b/, allow_value)

      allow(described_class).to receive(:new)
        .with(/(?-mix:a)|(?-mix:b)/, allow_value)
        .and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(described_class).to have_received(:new)
        .with(/(?-mix:a)|(?-mix:b)/, allow_value)
    end
  end

  describe '#append' do
    it 'returns nil' do
      expect(subject.append(instance_double(::FastIgnore::Patterns))).to be_nil
    end
  end

  describe '#match' do
    let(:first_line) { "#!/usr/bin/env ruby\n" }
    let(:rule) { /\bruby\b/ }
    let(:filename) { 'file.rb' }

    let(:candidate) { instance_double(::FastIgnore::Candidate, filename: filename, first_line: first_line) }

    context 'with an extension' do
      it 'returns nil without loading the first line' do
        expect(subject.match(candidate)).to be_nil
        expect(candidate).not_to have_received(:first_line)
      end
    end

    context 'without an extension' do
      let(:filename) { 'my_script' }

      context 'with a matching rule' do
        context 'when allowing' do
          it { expect(subject.match(candidate)).to be :allow }
        end

        context 'when not allowing' do
          let(:allow_value) { false }

          it { expect(subject.match(candidate)).to be :ignore }
        end
      end

      context 'with a non-matching rule' do
        let(:rule) { /\bbash\b/ }

        context 'when allowing' do
          it { expect(subject.match(candidate)).to be_nil }
        end

        context 'when not allowing' do
          let(:allow_value) { false }

          it { expect(subject.match(candidate)).to be_nil }
        end
      end
    end
  end
end
