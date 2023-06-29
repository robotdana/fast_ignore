# frozen_string_literal: true

RSpec.describe PathList::Matchers::ShebangRegexp do
  subject { described_class.build(builder, polarity) }

  let(:polarity) { :allow }
  let(:builder) { PathList::RegexpBuilder.new({ 'abcd' => nil }) }

  it { is_expected.to be_frozen }

  describe '#match' do
    let(:first_line) { "#!/usr/bin/env ruby\n" }
    let(:builder) { PathList::RegexpBuilder.new(['ruby']) }
    let(:filename) { 'file.rb' }

    let(:candidate) { instance_double(PathList::Candidate, first_line: first_line) }

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
        let(:builder) { PathList::RegexpBuilder.new(['bash']) }

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
    it { is_expected.to have_inspect_value 'PathList::Matchers::ShebangRegexp.new(/abcd/, :allow)' }
  end

  describe '#weight' do
    it { is_expected.to have_attributes(weight: 4.0) }
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
    it { is_expected.not_to be_squashable_with(PathList::Matchers::Allow) }

    it 'is squashable with the same polarity' do
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), :allow)

      expect(subject).to be_squashable_with(other)
    end

    it 'is not squashable with a different polarity' do
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), :ignore)

      expect(subject).not_to be_squashable_with(other)
    end
  end

  describe '#squash' do
    it 'squashes the regexps together' do
      subject
      other = described_class.build(PathList::RegexpBuilder.new({ 'b' => nil }), polarity)

      allow(described_class).to receive(:new).and_call_original
      squashed = subject.squash([subject, other])

      expect(squashed).to be_a(described_class)
      expect(squashed).not_to be subject
      expect(squashed).not_to be other

      expect(squashed).to be_like(described_class.build(PathList::RegexpBuilder.new({ 'abcd' => nil, 'b' => nil }),
                                                        polarity))
      expect(squashed).to be_like(described_class.new(/(?:abcd|b)/, polarity))
    end
  end

  describe '#compress_self' do
    it 'returns self' do
      expect(subject.compress_self).to be subject
    end
  end

  describe '#without_matcher' do
    it 'returns Blank if matcher is self' do
      expect(subject.without_matcher(subject)).to be PathList::Matchers::Blank
    end

    it 'returns self otherwise' do
      expect(subject.without_matcher(PathList::Matchers::Blank)).to be subject
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
