# frozen_string_literal: true

RSpec.describe PathList::RegexpBuilder do
  describe '.merge_parts_lists' do
    it 'returns the first value if only value' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b']]))
        .to eq ['a', :dir, 'b']
    end

    it 'returns the correct value from identical lists' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b'], ['a', :dir, 'b']]))
        .to eq ['a', :dir, 'b']
    end

    it 'returns the correct value for lists that start identical then fork to continue' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b'], ['a', :dir, 'b', :dir, 'c']]))
        .to eq ['a', :dir, 'b', [[], [:dir, 'c']]]
    end

    it 'simplifies a fork with one item' do
      expect(described_class.merge_parts_lists([[[['a', :dir, 'b']]]]))
        .to eq ['a', :dir, 'b']
    end

    it 'simplifies a fork with identical parts' do
      expect(described_class.merge_parts_lists([[[['a', :dir, 'b'], ['a', :dir, 'b']]]]))
        .to eq ['a', :dir, 'b']
    end

    it 'merges into a fork' do
      expect(described_class.merge_parts_lists([[[['a', :dir, 'b'], [:start_anchor]]], ['a', :dir, 'b']]))
        .to eq [[['a', :dir, 'b'], [:start_anchor]]]
    end

    it 'merges into a fork, complexly' do
      expect(described_class.merge_parts_lists([
        [[['a', :dir, 'b'], ['a', :dir, [['c', 'e'], ['f']]], [:start_anchor], [:start_anchor, 'z']]], ['a', :dir, 'b']
      ]))
        .to eq [[['a', :dir, [['b'], ['c', 'e'], ['f']]], [:start_anchor, [[], ['z']]]]]
    end

    it 'returns the correct value from differing lists with the same size' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b'], ['a', :dir, 'c']]))
        .to eq ['a', :dir, [['b'], ['c']]]
    end

    it 'returns the correct value from differing lists with different sizes' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b', 'c'], ['a', :dir, 'd']]))
        .to eq ['a', :dir, [['b', 'c'], ['d']]]
    end

    it 'returns the correct value from merging three items' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b', 'c'], ['a', :dir, 'd'], ['a', :dir, 'b', 'd']]))
        .to eq ['a', :dir, [['b', [['c'], ['d']]], ['d']]]
    end

    it 'returns the correct value when the initial value differs' do
      expect(described_class.merge_parts_lists([['a', :dir, 'b', 'c'], ['b', :dir, 'd'], ['a', :dir, 'b', 'd']]))
        .to eq [[['a', :dir, 'b', [['c'], ['d']]], ['b', :dir, 'd']]]
    end
  end
end
