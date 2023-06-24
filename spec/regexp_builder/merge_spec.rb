# frozen_string_literal: true

RSpec.describe PathList::RegexpBuilder::Merge do
  describe '.merge' do
    it 'returns the first value if only value' do
      expect(described_class.merge([{ 'a' => { dir: { 'b' => nil } } }]))
        .to eq('a' => { dir: { 'b' => nil } })
    end

    it 'returns the correct value from identical lists' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => nil } } },
        { 'a' => { dir: { 'b' => nil } } }
      ]))
        .to eq('a' => { dir: { 'b' => nil } })
    end

    it 'returns the correct value for lists that start identical then fork to continue' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => nil } } },
        { 'a' => { dir: { 'b' => { dir: { 'c' => nil } } } } }
      ]))
        .to eq('a' => { dir: { 'b' => { nil => nil, dir: { 'c' => nil } } } })
    end

    it 'merges into a fork' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => nil } }, start_anchor: nil },
        { 'a' => { dir: { 'b' => nil } } }
      ]))
        .to eq('a' => { dir: { 'b' => nil } }, start_anchor: nil)
    end

    it 'merges into a fork, complexly' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => nil } } },
        { 'a' => { dir: { 'c' => { 'e' => nil, 'f' => nil } } } },
        { any: nil },
        { any: { 'z' => nil } },
        { 'a' => { dir: { 'b' => nil } } }
      ]))
        .to eq('a' => { dir: { 'b' => nil, 'c' => { 'e' => nil, 'f' => nil } } }, any: { nil => nil, 'z' => nil })
    end

    it 'returns the correct value from differing lists with the same size' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => nil } } },
        { 'a' => { dir: { 'c' => nil } } }
      ]))
        .to eq('a' => { dir: { 'b' => nil, 'c' => nil } })
    end

    it 'returns the correct value from differing lists with different sizes' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => { 'c' => nil } } } },
        { 'a' => { dir: { 'd' => nil } } }
      ]))
        .to eq('a' => { dir: { 'b' => { 'c' => nil }, 'd' => nil } })
    end

    it 'returns the correct value from merging three items' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => { 'c' => nil } } } },
        { 'a' => { dir: { 'd' => nil } } },
        { 'a' => { dir: { 'b' => { 'd' => nil } } } }
      ]))
        .to eq('a' => { dir: { 'b' => { 'c' => nil, 'd' => nil }, 'd' => nil } })
    end

    it 'returns the correct value when the initial value differs' do
      expect(described_class.merge([
        { 'a' => { dir: { 'b' => { 'c' => nil } } } },
        { 'b' => { dir: { 'd' => nil } } },
        { 'a' => { dir: { 'b' => { 'd' => nil } } } }
      ]))
        .to eq('a' => { dir: { 'b' => { 'c' => nil, 'd' => nil } } }, 'b' => { dir: { 'd' => nil } })
    end

    it 'treats this regression case correctly' do
      expect(described_class.merge([
        { 'b' => { end_anchor: nil } },
        { 'bb' => { end_anchor: nil } },
        { any_dir: { 'a' => { end_anchor: nil } } },
        { any_dir: { 'd' => { end_anchor: nil } } },
        {
          'b' => { dir: nil },
          'bb' => { dir: nil },
          :any_dir => {
            'a' => { dir: nil },
            'd' => { dir: nil },
            'e' => { dir: nil }
          }
        }
      ])).to eq(
        'b' => { end_anchor: nil, dir: nil },
        'bb' => { end_anchor: nil, dir: nil },
        :any_dir => {
          'a' => { end_anchor: nil, dir: nil },
          'd' => { end_anchor: nil, dir: nil },
          'e' => { dir: nil }
        }
      )
    end
  end
end
