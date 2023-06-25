# typed: false
# frozen_string_literal: true

RSpec.describe PathList::GitIndex do
  shared_examples 'git ls-files' do
    context 'with basic files' do
      before do
        create_file_list 'foo/bar', 'foo/foo', 'bar/foo', 'bar/bar', 'baz', git_add: true
      end

      it 'matches git-ls output' do
        expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
          .and(eq(['bar/bar', 'bar/foo', 'baz', 'foo/bar', 'foo/foo']))
      end

      it 'can be given the file path exactly' do
        expect(described_class.files(Dir.pwd)).to eq(`git ls-files -z`.split("\0"))
          .and(eq(['bar/bar', 'bar/foo', 'baz', 'foo/bar', 'foo/foo']))
      end

      context 'with sparse checkout' do
        before do
          `git commit -m COMMIT`
          `git sparse-checkout init`
        end

        it 'matches git-ls output' do
          expect(File.exist?('bar/bar')).to be false

          expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
            .and(eq(['bar/bar', 'bar/foo', 'baz', 'foo/bar', 'foo/foo']))
        end
      end
    end

    context 'with intent to add file' do
      before do
        create_file 'x', path: 'foo', git_add: false
        `git add -N foo`
      end

      it 'matches git-ls output' do
        expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
          .and(eq(['foo']))
      end
    end

    context 'with file with newline in name' do
      before do
        create_file path: "foo\nbar", git_add: true
      end

      it 'matches git-ls output' do
        expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
          .and(eq(["foo\nbar"]))
      end
    end

    context 'with file with space in name' do
      before do
        create_file path: 'foo bar', git_add: true
      end

      it 'matches git-ls output' do
        expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
          .and(eq(['foo bar']))
      end
    end

    context 'with a non-ascii file name' do
      before do
        create_file path: '💖', git_add: true
      end

      it 'matches git-ls output' do
        expect(described_class.files).to eq(`git -c core.quotePath=off ls-files -z`.split("\0"))
          .and(eq(['💖']))
      end
    end

    context 'with file with long name' do
      before do
        create_file_list 'foo/bar', "foo/#{'bar' * 60}", 'foo/baz', git_add: true
      end

      it 'matches git-ls output' do
        expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
          .and(eq(['foo/bar', "foo/#{'bar' * 60}", 'foo/baz']))
      end
    end
  end

  describe '.files' do
    context 'with no git' do
      around do |example|
        within_temp_dir(git_init: false) { example.run }
      end

      it 'raises an error' do
        expect { described_class.files }.to raise_error(described_class::Error)
      end

      it 'raises an error when .git/index file is empty' do
        create_file '', path: '.git/index'

        expect { described_class.files }.to raise_error(described_class::Error)
      end

      it 'raises an error when .git/index file is a non recognized version' do
        create_file "DIRC\0\0\0\x5\0\0\0\0", path: '.git/index'

        expect { described_class.files }.to raise_error(described_class::Error, "Unrecognized git index version '5'")
      end
    end

    context 'with git' do
      around do |example|
        within_temp_dir(git_init: true) { example.run }
      end

      describe 'index version 2' do
        before { `git update-index --index-version=2` }

        it_behaves_like 'git ls-files'

        context 'with split index' do
          before { `git update-index --split-index --index-version=2` }

          it_behaves_like 'git ls-files'
        end
      end

      describe 'index version 3' do
        before { `git update-index --index-version=3` }

        it_behaves_like 'git ls-files'

        context 'with split index' do
          before { `git update-index --split-index --index-version=3` }

          it_behaves_like 'git ls-files'
        end
      end

      describe 'index version 4' do
        before { `git update-index --index-version=4` }

        it_behaves_like 'git ls-files'

        context 'with split index' do
          before { `git update-index --split-index --index-version=4` }

          it_behaves_like 'git ls-files'
        end
      end

      describe 'split index' do
        before do
          `git config core.splitIndex true`
          `git update-index --split-index`
        end

        it_behaves_like 'git ls-files'

        context 'with a deleted file in the middle of a list' do
          it 'matches git-ls output' do
            create_file_list 'foo/bar', 'foo/foo', 'bar/foo', 'bar/bar', 'baz'

            `git update-index --split-index`
            `rm ./baz`
            `git rm baz`

            expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
              .and(eq(['bar/bar', 'bar/foo', 'foo/bar', 'foo/foo']))
          end
        end

        describe 'compression' do
          [63, 64, 65, 90, 127, 128, 129, 300, 600].each do |n|
            context "with #{n} files deleted" do
              it 'matches git-ls output' do
                filenames = Array.new(n).map.with_index { |_, i| "dir/#{i}" }
                create_file_list(*filenames, 'foo', git_add: true)

                `git update-index --split-index`
                `rm -rf ./dir/*`
                `git rm dir/*`

                expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
                  .and(eq(['foo']))
              end
            end

            context "with even of #{n} files deleted" do
              it 'matches git-ls output' do
                filenames = Array.new(n).map.with_index { |_, i| "dir/#{i}" }

                create_file_list(*filenames, git_add: true)

                `git update-index --split-index`
                `rm -rf ./dir/*2 ./dir/*4 ./dir/*6 ./dir/*8 ./dir/*0`
                `git rm dir/*2 dir/*4 dir/*6 dir/*8 dir/*0`

                expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
                  .and(match_array(filenames.reject { |i| i.sub(%r{^dir/}, '').to_i.even? }))
              end
            end

            context "with #{n} files moved" do
              it 'matches git-ls output' do
                filenames = Array.new(n).map.with_index { |_, i| "dir/#{i}" }

                create_file_list(*filenames, git_add: true)
                `git commit --no-verify -m COMMIT`
                `git update-index --split-index`
                `git mv dir dir2`

                expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
                  .and(match_array(filenames.map { |f| f.sub('dir', 'dir2') }))
              end
            end

            context "with #{n} files updated" do
              it 'matches git-ls output' do
                filenames = Array.new(n).map.with_index { |_, i| "dir/#{i}" }

                create_file_list(*filenames, git_add: true)

                `git update-index --split-index`
                sleep 0.1
                `touch dir/*`

                expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
                  .and(match_array(filenames))
              end
            end

            context "with #{n} files in place" do
              it 'matches git-ls output' do
                filenames = Array.new(n).map.with_index { |_, i| "dir/#{i}" }

                create_file_list(*filenames, git_add: true)

                `git update-index --split-index`

                expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
                  .and(match_array(filenames))
              end
            end
          end
        end

        context 'with a replaced file' do
          it 'matches git-ls output' do
            create_file_list 'foo/bar', 'foo/foo', 'bar/foo', 'bar/bar', 'baz', git_add: true

            create_file 'CONTENT', path: 'bat/zero', git_add: true

            `git update-index --split-index`
            # `git commit --no-verify -m COMMIT`
            `git mv bat/zero bat/one`
            # `git commit --no-verify -m COMMIT`

            expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
              .and(eq(['bar/bar', 'bar/foo', 'bat/one', 'baz', 'foo/bar', 'foo/foo']))
          end
        end

        context 'with an added file' do
          it 'matches git-ls output' do
            create_file_list 'foo/bar', 'foo/foo', 'bar/foo', 'bar/bar', 'baz', git_add: true

            `git update-index --split-index`

            create_file path: 'bat/zero', git_add: true

            expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
              .and(eq(['bar/bar', 'bar/foo', 'bat/zero', 'baz', 'foo/bar', 'foo/foo']))
          end
        end

        context 'with an invalid unignorable extension' do
          it 'raises an error' do
            create_file_list 'foo/bar', git_add: true

            File.write('.git/index', File.read('.git/index').gsub!('link', 'beep'))

            expect { described_class.files }.to raise_error(GitLS::Error)
          end
        end

        context 'with an ignorable extension' do
          it "doesn't raises an error" do
            create_file_list 'foo/bar', git_add: true
            `git update-index --force-untracked-cache`

            expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
              .and(eq(['foo/bar']))
          end
        end

        context 'with an unknown but ignorable extension' do
          it "doesn't raises an error" do
            create_file_list 'foo/bar', git_add: true
            `git update-index --force-untracked-cache`

            File.write('.git/index', File.read('.git/index').gsub!('UNTR', 'BEEP'))

            expect(described_class.files).to eq(`git ls-files -z`.split("\0"))
              .and(eq(['foo/bar']))
          end
        end
      end
    end
  end
end
