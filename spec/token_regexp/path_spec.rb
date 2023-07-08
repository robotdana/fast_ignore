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
end
