# frozen_string_literal: true

RSpec.describe PathList::RegexpBuilder do
  describe '.union' do
    it 'returns the first value if only value' do
      expect(described_class.union([described_class.new(['a', :dir, 'b'])]))
        .to eq described_class.new(['a', :dir, 'b'])
    end

    it 'returns the correct value from identical lists' do
      expect(described_class.union([described_class.new(['a', :dir, 'b']), described_class.new(['a', :dir, 'b'])]))
        .to eq described_class.new(['a', :dir, 'b'])
    end

    it 'returns the correct value for lists that start identical then fork to continue' do
      expect(described_class.union([
        described_class.new(['a', :dir, 'b']),
        described_class.new(['a', :dir, 'b', :dir, 'c'])
      ]))
        .to eq described_class.new(['a', :dir, 'b', [[], [:dir, 'c']]])
    end

    it 'simplifies a fork with one item' do
      expect(described_class.union([described_class.new([[['a', :dir, 'b']]])]))
        .to eq described_class.new(['a', :dir, 'b'])
    end

    it 'simplifies a fork with identical parts' do
      expect(described_class.union([described_class.new([[['a', :dir, 'b'], ['a', :dir, 'b']]])]))
        .to eq described_class.new(['a', :dir, 'b'])
    end

    it 'merges into a fork' do
      expect(described_class.union([
        described_class.new([[['a', :dir, 'b'], [:start_anchor]]]),
        described_class.new(['a', :dir, 'b'])
      ]))
        .to eq described_class.new([[['a', :dir, 'b'], [:start_anchor]]])
    end

    it 'merges into a fork, complexly' do
      expect(described_class.union([
        described_class.new([
          [
            ['a', :dir, 'b'], ['a', :dir, [['c', 'e'], ['f']]], [:any],
            [:any, 'z']
          ]
        ]), described_class.new(['a', :dir, 'b'])
      ]))
        .to eq described_class.new([[['a', :dir, [['b'], ['c', 'e'], ['f']]], [:any, [[], ['z']]]]])
    end

    it 'returns the correct value from differing lists with the same size' do
      expect(described_class.union([described_class.new(['a', :dir, 'b']), described_class.new(['a', :dir, 'c'])]))
        .to eq described_class.new(['a', :dir, [['b'], ['c']]])
    end

    it 'returns the correct value from differing lists with different sizes' do
      expect(described_class.union([described_class.new(['a', :dir, 'b', 'c']), described_class.new(['a', :dir, 'd'])]))
        .to eq described_class.new(['a', :dir, [['b', 'c'], ['d']]])
    end

    it 'returns the correct value from merging three items' do
      expect(described_class.union([
        described_class.new(['a', :dir, 'b', 'c']), described_class.new(['a', :dir, 'd']),
        described_class.new(['a', :dir, 'b', 'd'])
      ]))
        .to eq described_class.new(['a', :dir, [['b', [['c'], ['d']]], ['d']]])
    end

    it 'returns the correct value when the initial value differs' do
      expect(described_class.union([
        described_class.new(['a', :dir, 'b', 'c']), described_class.new(['b', :dir, 'd']),
        described_class.new(['a', :dir, 'b', 'd'])
      ]))
        .to eq described_class.new([[['a', :dir, 'b', [['c'], ['d']]], ['b', :dir, 'd']]])
    end
  end
end
