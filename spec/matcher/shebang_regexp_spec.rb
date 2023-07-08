# frozen_string_literal: true

RSpec.describe PathList::Matcher::ShebangRegexp do
  subject { described_class.build(regexp_tokens, polarity) }

  let(:polarity) { :allow }
  let(:regexp_tokens) { [['abcd']] }

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:shebang) { "#!/usr/bin/env ruby\n" }
    let(:regexp_tokens) { [['ruby']] }
    let(:filename) { 'file.rb' }

    let(:candidate) { instance_double(PathList::Candidate, 'candidate', shebang: shebang) }

    context 'without an extension' do
      let(:filename) { 'my_script' }

      context 'with a matching rule' do
        context 'when allowing' do
          it { expect(subject.match(candidate)).to be :allow }
        end

        context 'when not allowing' do
          let(:polarity) { :ignore }

          it { expect(subject.match(candidate)).to be :ignore }
        end
      end

      context 'with a non-matching rule' do
        let(:regexp_tokens) { [['bash']] }

        context 'when allowing' do
          it { expect(subject.match(candidate)).to be_nil }
        end

        context 'when not allowing' do
          let(:polarity) { :ignore }

          it { expect(subject.match(candidate)).to be_nil }
        end
      end
    end
  end

  describe '#inspect' do
    it { is_expected.to have_inspect_value 'PathList::Matcher::ShebangRegexp.new(/abcd/, :allow)' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 4) }
  end

  describe '#polarity' do
    context 'when polarity is ignore' do
      let(:polarity) { :ignore }

      it { is_expected.to have_attributes(polarity: :ignore) }
    end

    context 'when polarity is allow' do
      let(:polarity) { :allow }

      it { is_expected.to have_attributes(polarity: :allow) }
    end
  end

  describe '#squashable_with?' do
    it { is_expected.to be_squashable_with(subject) }
    it { is_expected.not_to be_squashable_with(PathList::Matcher::Allow) }

    it 'is squashable with the same polarity' do
      other = described_class.build([['b']], :allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different polarity' do
      other = described_class.build([['b']], :ignore)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.build([['b']], polarity)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other], false)

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(squashed).to be_like(described_class.build([['abcd'], ['b']], polarity))
      expect(squashed).to be_like(described_class.new(/(?:b|abcd)/, polarity))
    end
  end

  describe '#dir_matcher' do
    it 'returns self' do
      expect(subject.dir_matcher).to be subject
    end
  end

  describe '#file_matcher' do
    it 'returns self' do
      expect(subject.file_matcher).to be subject
    end
  end
end
