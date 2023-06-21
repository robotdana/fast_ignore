# frozen_string_literal: true

RSpec.describe PathList::Matchers::ShebangRegexp do
  subject { described_class.build(builder, allow_value) }

  let(:allow_value) { true }
  let(:builder) { PathList::RegexpBuilder.new(['abc']) }

  it { is_expected.to be_frozen }

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matchers::ShebangRegexp.new(/abc/i, true)' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 4.0) }
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }

    it 'is squashable with the same property values' do
      other = described_class.build(PathList::RegexpBuilder.new(['b']), allow_value)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different allow value' do
      other = described_class.build(PathList::RegexpBuilder.new(['b']), !allow_value)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.build(PathList::RegexpBuilder.new(['b']), allow_value)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(squashed).to eq(described_class.build(PathList::RegexpBuilder.new([[['abc'], ['b']]]), allow_value))
      expect(squashed).to eq(described_class.new(/(?:abc|b)/i, allow_value))
    end
  end

  describe '#match' do
    let(:first_line) { "#!/usr/bin/env ruby\n" }
    let(:builder) { PathList::RegexpBuilder.new(['ruby']) }
    let(:filename) { 'file.rb' }

    let(:candidate) { instance_double(PathList::Candidate, filename: filename, first_line: first_line) }

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
        let(:builder) { PathList::RegexpBuilder.new(['bash']) }

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
