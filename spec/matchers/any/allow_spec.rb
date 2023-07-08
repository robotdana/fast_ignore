# frozen_string_literal: true

RSpec.describe PathList::Matchers::Any::Allow do
  subject { described_class.new(matchers) }

  let(:matcher_allow_a) do
    instance_double(PathList::Matchers::Base, weight: 1, polarity: :allow, squashable_with?: false)
  end
  let(:matcher_allow_b) do
    instance_double(PathList::Matchers::Base, weight: 2, polarity: :allow, squashable_with?: false)
  end
  let(:matcher_allow_c) do
    instance_double(PathList::Matchers::Base, weight: 3, polarity: :allow, squashable_with?: false)
  end
  let(:matcher_allow_d) do
    instance_double(PathList::Matchers::Base, weight: 4, polarity: :allow, squashable_with?: false)
  end

  let(:matchers) { [matcher_allow_a, matcher_allow_b, matcher_allow_c] }

  it { is_expected.to be_frozen }

  # match is covered in ../any_spec.rb

  # build is covered in ../any_spec.rb
  describe '.build' do
    it 'delegates build to the Any class' do
      allow(PathList::Matchers::Any).to receive(:build).and_call_original
      expect(described_class.build([
        matcher_allow_a,
        matcher_allow_b,
        matcher_allow_c
      ])).to be_like(
        described_class.new([
          matcher_allow_a, matcher_allow_b, matcher_allow_c
        ])
      )
      expect(PathList::Matchers::Any).to have_received(:build)
    end
  end

  describe '#inspect' do
    it do
      expect(subject).to have_inspect_value <<~INSPECT.chomp
        PathList::Matchers::Any::Allow.new([
          #{matcher_allow_a.inspect},
          #{matcher_allow_b.inspect},
          #{matcher_allow_c.inspect}
        ])
      INSPECT
    end
  end

  describe '#weight' do
    it 'is the matchers halved' do
      expect(subject.weight).to eq 3
    end
  end

  describe '#polarity' do
    it 'is allow' do
      expect(subject.polarity).to be :allow
    end
  end

  describe '#squashable_with?' do
    it { is_expected.not_to be_squashable_with(subject.dup) }
  end

  describe '#compress_self' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:compress_self).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:compress_self).and_return(matcher_allow_b)
      allow(matcher_allow_c).to receive(:compress_self).and_return(matcher_allow_c)
      expect(subject.compress_self).to be subject
      expect(matcher_allow_a).to have_received(:compress_self)
      expect(matcher_allow_b).to have_received(:compress_self)
      expect(matcher_allow_c).to have_received(:compress_self)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:compress_self).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:compress_self).and_return(matcher_allow_d)
      allow(matcher_allow_c).to receive(:compress_self).and_return(matcher_allow_c)
      new_matcher = subject.compress_self
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_allow_c,
        matcher_allow_d
      ]))
      expect(matcher_allow_a).to have_received(:compress_self)
      expect(matcher_allow_b).to have_received(:compress_self)
      expect(matcher_allow_c).to have_received(:compress_self)
    end
  end

  describe '#dir_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:dir_matcher).and_return(matcher_allow_b)
      allow(matcher_allow_c).to receive(:dir_matcher).and_return(matcher_allow_c)
      expect(subject.dir_matcher).to be subject
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_allow_b).to have_received(:dir_matcher)
      expect(matcher_allow_c).to have_received(:dir_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:dir_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:dir_matcher).and_return(matcher_allow_d)
      allow(matcher_allow_c).to receive(:dir_matcher).and_return(matcher_allow_c)
      new_matcher = subject.dir_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_allow_c,
        matcher_allow_d
      ]))
      expect(matcher_allow_a).to have_received(:dir_matcher)
      expect(matcher_allow_b).to have_received(:dir_matcher)
      expect(matcher_allow_c).to have_received(:dir_matcher)
    end
  end

  describe '#file_matcher' do
    it 'passes to its matchers, returns self if all are unchanged' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:file_matcher).and_return(matcher_allow_b)
      allow(matcher_allow_c).to receive(:file_matcher).and_return(matcher_allow_c)
      expect(subject.file_matcher).to be subject
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_allow_b).to have_received(:file_matcher)
      expect(matcher_allow_c).to have_received(:file_matcher)
    end

    it 'passes to its matchers, returns a new matcher if any are changed' do
      allow(matcher_allow_a).to receive(:file_matcher).and_return(matcher_allow_a)
      allow(matcher_allow_b).to receive(:file_matcher).and_return(matcher_allow_d)
      allow(matcher_allow_c).to receive(:file_matcher).and_return(matcher_allow_c)
      new_matcher = subject.file_matcher
      expect(new_matcher).not_to be subject
      expect(new_matcher).to be_like(described_class.new([
        matcher_allow_a,
        matcher_allow_c,
        matcher_allow_d
      ]))
      expect(matcher_allow_a).to have_received(:file_matcher)
      expect(matcher_allow_b).to have_received(:file_matcher)
      expect(matcher_allow_c).to have_received(:file_matcher)
    end
  end
end
