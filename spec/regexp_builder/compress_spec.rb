# RSpec.describe PathList::RegexpBuilder::Compress do
#   describe '.compress' do
#     # bug it should leave this alone
#     it 'shrinks \A[^/]*\z to \A[^\]' do
#       expect(described_class.compress([:start_anchor, :any_non_dir, :end_anchor]))
#         .to eq [:start_anchor, :one_non_dir]
#     end

#     it 'shrinks \A(?:.*/)?foo to (?:\A|/)foo' do
#       expect(described_class.compress([:start_anchor, :any_dir, 'foo']))
#         .to eq [:dir_or_start_anchor, 'foo']
#     end

#     it 'shrinks \A/(?:.*/)?[^\]*foo to foo' do
#       expect(described_class.compress([:start_anchor, :any_dir, 'foo']))
#         .to eq [:dir_or_start_anchor, 'foo']
#     end
#   end
# end
