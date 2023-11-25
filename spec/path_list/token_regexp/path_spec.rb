# frozen_string_literal: true

RSpec.describe PathList::TokenRegexp::Path do
  describe '#exact_path?' do
    it 'is true for fixed path input from path' do
      expect(described_class.new_from_path('this/that/another')).to be_exact_path
    end

    it 'is true for fixed path input entered manually' do
      path = [:start_anchor, 'this', :dir, 'that', :end_anchor]
      expect(described_class.new(path)).to be_exact_path
    end

    it 'is false for path with no start anchor' do
      path = ['this', :dir, 'that', :end_anchor]
      expect(described_class.new(path)).not_to be_exact_path
    end

    it 'is false for path with no end anchor' do
      path = [:start_anchor, 'this', :dir, 'that']
      expect(described_class.new(path)).not_to be_exact_path
    end

    it 'is false for path with any in it' do
      path = [:start_anchor, 'this', :any_dir, 'that', :end_anchor]
      expect(described_class.new(path)).not_to be_exact_path
    end
  end

  describe '.new_from_path' do
    it 'works for unix shaped paths' do
      expect(described_class.new_from_path('/a/b/c/d').parts)
        .to eq [:start_anchor, :dir, 'a', :dir, 'b', :dir, 'c', :dir, 'd', :end_anchor]
    end

    it 'works for windows shaped paths' do
      expect(described_class.new_from_path('C:/a/b/c/d').parts)
        .to eq [:start_anchor, 'C:', :dir, 'a', :dir, 'b', :dir, 'c', :dir, 'd', :end_anchor]
    end

    it 'works for unix shaped root path' do
      expect(described_class.new_from_path('/').parts)
        .to eq [:start_anchor, :dir, :end_anchor]
    end

    it 'works for windows shaped root path' do
      expect(described_class.new_from_path('C:/').parts)
        .to eq [:start_anchor, 'C:', :dir, :end_anchor]
    end

    it 'works for windows shaped root path, case insensitively' do
      allow(PathList::CanonicalPath).to receive(:case_insensitive?).and_return(true)

      expect(described_class.new_from_path('C:/').parts)
        .to eq [:start_anchor, 'c:', :dir, :end_anchor]
    end
  end

  describe '#compress' do
    it 'works for unix shaped paths' do
      expect(described_class.new([
        :start_anchor, :dir, :any_dir, 'a', :dir, 'b', :dir, :any_dir,
        :end_anchor
      ]).compress.parts)
        .to eq [:dir, 'a', :dir, 'b', :dir]
    end

    it 'works for windows shaped paths' do
      expect(described_class.new([
        :start_anchor, 'D:', :dir, :any_dir, 'a', :dir, 'b', :dir, :any_dir,
        :end_anchor
      ]).compress.parts)
        .to eq [:start_anchor, 'D:', :dir, :any_dir, 'a', :dir, 'b', :dir]
    end
  end

  describe 'ancestors' do
    it 'works for unix shaped paths' do
      expect(described_class.new_from_path('/a/b/c/d').ancestors.map(&:parts)).to eq [
        [:start_anchor, :dir, :end_anchor],
        [:start_anchor, :dir, 'a', :end_anchor],
        [:start_anchor, :dir, 'a', :dir, 'b', :end_anchor],
        [:start_anchor, :dir, 'a', :dir, 'b', :dir, 'c', :end_anchor]
      ]
    end

    it 'works for windows shaped paths' do
      expect(described_class.new_from_path('C:/a/b/c/d').ancestors.map(&:parts)).to eq [
        [:start_anchor, 'C:', :dir, :end_anchor],
        [:start_anchor, 'C:', :dir, 'a', :end_anchor],
        [:start_anchor, 'C:', :dir, 'a', :dir, 'b', :end_anchor],
        [:start_anchor, 'C:', :dir, 'a', :dir, 'b', :dir, 'c', :end_anchor]
      ]
    end
  end
end
