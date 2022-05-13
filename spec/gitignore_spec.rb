# frozen_string_literal: true

RSpec.describe FastIgnore do
  around { |e| within_temp_dir { e.run } }

  let(:root) { Dir.pwd }

  shared_examples 'gitignore: true' do
    describe 'Patterns read from a .gitignore file in the same directory as the path, or in any parent directory' do
      # (up to the toplevel of the work tree) # we consider root the root

      describe 'with patterns in the higher level files being overridden by those in lower level files.' do
        before do
          create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d'
        end

        it 'matches files in context by files' do
          gitignore '**/b/d'
          gitignore 'b/c', path: 'a/.gitignore'

          expect(subject).not_to match_files('b/c', 'a/.gitignore')
          expect(subject).to match_files('a/b/d', 'a/b/c', 'b/d')
        end

        it 'overrides parent rules in lower level files' do
          gitignore '**/b/d'
          gitignore '!b/d', 'b/c', path: 'a/.gitignore'

          expect(subject).not_to match_files('a/b/d', 'b/c', 'a/.gitignore')
          expect(subject).to match_files('a/b/c', 'b/d')
        end

        it 'overrides parent rules in lower level files with 3 levels' do
          gitignore '**/b/d', '**/b/c'
          gitignore '!b/d', 'b/c', path: 'a/.gitignore'
          gitignore 'd', '!c', path: 'a/b/.gitignore'

          expect(subject).not_to match_files('a/b/c', 'a/.gitignore', 'a/b/.gitignore', '.gitignore')
          expect(subject).to match_files('b/c', 'b/d', 'a/b/d')
        end

        it 'overrides parent rules in lower level files with 3 levels with allowed?' do
          gitignore '**/b/d', '**/b/c'
          gitignore '!b/d', 'b/c', path: 'a/.gitignore'
          gitignore 'd', '!c', path: 'a/b/.gitignore'

          # rubocop:disable RSpec/DescribedClass
          # i want a new one each time
          expect(FastIgnore.new).to be_allowed('a/b/c')
          expect(FastIgnore.new).not_to be_allowed('a/b/d')
          expect(FastIgnore.new).not_to be_allowed('b/d')
          expect(FastIgnore.new).not_to be_allowed('b/c')
          # rubocop:enable RSpec/DescribedClass
        end

        it 'overrides parent negations in lower level files' do
          gitignore '**/b/*', '!**/b/d'
          gitignore 'b/d', '!b/c', path: 'a/.gitignore'

          expect(subject).not_to match_files('b/d', 'a/b/c', 'a/.gitignore')
          expect(subject).to match_files('b/c', 'a/b/d')
        end
      end

      describe 'Patterns read from $GIT_DIR/info/exclude' do
        before do
          create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d'

          gitignore 'b/d'
          gitignore 'a/b/c', path: '.git/info/exclude'
        end

        it 'recognises .git/info/exclude files' do
          expect(subject).not_to match_files('a/b/d', 'b/c')
          expect(subject).to match_files('a/b/c', 'b/d')
        end
      end
    end

    it 'ignore .git by default' do
      create_file_list '.gitignore', '.git/WHATEVER', 'WHATEVER'

      expect(subject).to match_files('.git/WHATEVER')
      expect(subject).not_to match_files('WHATEVER')
    end
  end

  describe '.new' do
    subject { described_class.new(relative: true, **args) }

    let(:args) { {} }
    let(:gitignore_path) { File.join(root, '.gitignore') }

    it_behaves_like 'gitignore: true'
  end

  describe 'git ls-files' do
    subject do
      `git init && git -c core.excludesfile='' add -N .`
      `git -c core.excludesfile='' ls-files`.split("\n")
    end

    it_behaves_like 'gitignore: true'
  end
end
