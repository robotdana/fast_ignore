# frozen_string_literal: true

require_relative '../lib/fast_ignore/backports/delete_prefix_suffix'
RSpec.describe FastIgnore::Backports::DeletePrefixSuffix do
  using described_class

  describe '#delete_prefix!' do
    it 'matches the documentation' do
      # dup because rubocop insists on frozen string literals
      expect('hello'.dup.delete_prefix!('hel')).to eq('lo')
      expect('hello'.dup.delete_prefix!('llo')).to be_nil
    end
  end

  describe '#delete_suffix!' do
    it 'matches the documentation' do
      # dup because rubocop insists on frozen string literals
      expect('hello'.dup.delete_suffix!('llo')).to eq('he')
      expect('hello'.dup.delete_suffix!('hel')).to be_nil
    end
  end

  describe '#delete_prefix' do
    it 'matches the documentation' do
      expect('hello'.delete_prefix('hel')).to eq('lo')
      expect('hello'.delete_prefix('llo')).to eq('hello')
    end
  end

  describe '#delete_suffix' do
    it 'matches the documentation' do
      expect('hello'.delete_suffix('llo')).to eq('he')
      expect('hello'.delete_suffix('hel')).to eq('hello')
    end
  end
end
