# frozen_string_literal: true

RSpec.describe PathList::Candidate do
  subject(:candidate) do
    described_class.new(
      full_path,
      filename,
      directory,
      exists,
      content,
      path_list,
      parent_if_directory
    )
  end

  let(:full_path) { "/path/from/root/#{filename}" }
  let(:filename) { 'filename' }
  let(:directory) { false }
  let(:exists) { true }
  let(:content) { '' }
  let(:path_list) { PathList }
  let(:parent_if_directory) { true }

  describe '#original_inspect' do
    it 'returns the default inspect' do
      match = candidate.original_inspect.match(
        /#<PathList::Candidate:0x\h{16} (?<ivars>.*)>\z/
      )
      expect(match).to be_truthy
      expect(match.named_captures['ivars'].split(', ')).to contain_exactly(
        '@full_path="/path/from/root/filename"',
        '@filename="filename"',
        '@directory=false',
        '@exists=true',
        '@first_line=""',
        '@path_was=[]',
        '@path_list=PathList',
        '@parent_if_directory=true'
      )
    end
  end

  describe '#inspect' do
    it 'returns the path with some bits for ease of reading' do
      expect(candidate.inspect).to eq '#<PathList::Candidate /path/from/root/filename>'
    end
  end
end
