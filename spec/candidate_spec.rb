RSpec.describe FastIgnore::Candidate do
  let(:full_path) { "/path/from/root/#{filename}" }
  let(:filename) { "filename" }
  let(:directory) { false }
  let(:exists) { true }
  let(:content) { "" }
  let(:path_list) { FastIgnore::PathList }
  let(:parent_if_directory) { true }
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

  describe '#original_inspect' do
    it 'returns the default inspect' do
      expect(candidate.original_inspect)
        .to match(
          %r{
            \A
            \#<FastIgnore::Candidate:0x\h{16}
            \ @full_path="/path/from/root/filename",
            \ @filename="filename",
            \ @directory=false,
            \ @exists=true,
            \ @first_line="",
            \ @path_was=\[\],
            \ @path_list=FastIgnore::PathList,
            \ @parent_if_directory=true>
            \z
          }x
        )
    end
  end

  describe '#inspect' do
    it 'returns the path with some bits for ease of reading' do
      expect(candidate.inspect).to eq "#<FastIgnore::Candidate /path/from/root/filename>"
    end
  end
end
