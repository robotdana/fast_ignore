# frozen_string_literal: true

RSpec.describe PathList::RegexpBuilder do
  describe '#exact_string?' do
    it 'is true for fixed path input from path' do
      expect(described_class.new_from_path('this/that/another')).to be_exact_string
    end

    it 'is true for fixed path input entered manually' do
      path = { start_anchor: { 'this' => { dir: { 'that' => { end_anchor: nil } } } } }
      expect(described_class.new(path)).to be_exact_string
    end

    it 'is false for path with no start anchor' do
      path = { '/' => { 'this' => { dir: { 'that' => { end_anchor: nil } } } } }
      expect(described_class.new(path)).not_to be_exact_string
    end

    it 'is false for path with no end anchor' do
      path = { start_anchor: { 'this' => { dir: { 'that' => nil } } } }
      expect(described_class.new(path)).not_to be_exact_string
    end

    it 'is false for path with any in it' do
      path = { start_anchor: { 'this' => { any_dir: { 'that' => { end_anchor: nil } } } } }
      expect(described_class.new(path)).not_to be_exact_string
    end
  end
end
