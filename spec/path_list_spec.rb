# frozen_string_literal: true

require 'pathname'

RSpec.describe PathList do
  within_temp_dir

  it 'has a version number' do
    expect(PathList::VERSION).not_to be_nil
  end

  describe '.new' do
    it 'returns all files when there is no gitignore' do
      create_file_list 'foo', 'bar'
      expect(subject).to allow_exactly('foo', 'bar')
    end

    it 'ignores the given gitignore file and returns all files anyway' do
      gitignore 'foo', 'bar'

      expect(subject).to allow_files('foo', 'bar')
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
    end
  end

  it 'is enumerable' do
    expect(subject).to be_a Enumerable
  end

  describe '#each' do
    it 'returns an enumerator' do
      expect(subject.each).to be_a Enumerator
    end

    context 'when given root as a child dir' do
      subject(:to_a) { described_class.new.each(Dir.pwd + '/bar').to_a }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'

        expect(subject).to contain_exactly('foo', 'baz')
      end
    end

    context 'when given root as a parent dir' do
      subject { described_class.gitignore(root: '../') }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'
        gitignore 'baz'

        Dir.chdir('bar') do
          expect(subject.each('../').to_a).to contain_exactly('bar/foo', 'fez', '.gitignore')
        end
      end
    end

    context 'when given root with a trailing slash' do
      subject(:to_a) { described_class.new.each(Dir.pwd + '/bar/').to_a }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/bar'

        expect(subject).to contain_exactly('foo', 'baz')
      end
    end
  end

  describe '#include?' do
    it 'returns false nonexistent files' do
      expect(subject.include?('utter/nonsense')).to be false
    end
  end

  describe '#match?' do
    it 'includes directories' do
      create_file_list 'a/b'

      expect(subject.match?('a')).to be true
    end

    it 'includes directories when given trailing slash' do
      create_file_list 'a/b'
      expect(subject.match?('a/')).to be true
    end

    it 'can be shortcut with directory:' do
      create_file_list 'a'
      expect(subject.match?('a', directory: false)).to be true
    end

    it 'can be lied to with directory: false' do
      create_file_list 'a/b'
      expect(subject.match?('a', directory: false)).to be true
    end

    it 'can be lied to with directory: true' do
      create_file_list 'a/b'
      expect(subject.match?('a/b', directory: true)).to be true
    end
  end

  describe '.gitignore' do
    subject(:path_list) { described_class.gitignore }

    it 'returns all files when there is no gitignore' do
      create_file_list 'foo', 'bar'

      expect(subject).to allow_exactly('foo', 'bar')
    end

    it 'creates a sensible list of matchers' do
      gitignore 'foo', 'bar/'

      expect(subject.send(:dir_matcher)).to be_like PathList::Matchers::LastMatch.new([
        PathList::Matchers::Allow,
        PathList::Matchers::CollectGitignore.new(
          PathList::Matchers::PathRegexp.new(%r{\A#{Regexp.escape(Dir.pwd).downcase}(?:\z|/)}, :allow),
          PathList::Matchers::Mutable.new(
            PathList::Matchers::PathRegexp.new(
              %r{\A#{Regexp.escape(Dir.pwd).downcase}/(?:.*/)?(?:foo\z|bar\z)}, :ignore
            )
          )
        ),
        PathList::Matchers::PathRegexp.new(%r{/\.git\z}, :ignore)
      ])

      expect(subject.send(:file_matcher)).to be_like PathList::Matchers::LastMatch::Two.new([
        PathList::Matchers::Allow,
        PathList::Matchers::Mutable.new(
          PathList::Matchers::PathRegexp.new(%r{\A#{Regexp.escape(Dir.pwd).downcase}/(?:.*/)?foo\z}, :ignore)
        )
      ])
    end

    it 'can match files with case equality' do
      create_file_list 'foo', 'bar'
      gitignore 'foo'

      expect(subject === 'bar').to be true # rubocop:disable Style/CaseEquality
      expect(subject === 'foo').to be false # rubocop:disable Style/CaseEquality
    end

    it 'matches uppercase paths to lowercase patterns' do
      gitignore 'foo'

      expect(subject).to match_files('FOO')
    end

    it 'matches lowercase paths to uppercase patterns' do
      gitignore 'FOO'

      expect(subject).to match_files('foo')
    end

    context 'with soft links to nowhere' do
      before do
        create_file_list 'foo_target', '.gitignore'
        create_symlink('foo' => 'foo_target')
        FileUtils.rm('foo_target')
      end

      it 'rescues errors in PathList methods', :aggregate_failures do
        expect(subject.include?('foo')).to be false
        expect(subject.match?('foo')).to be true
        expect(subject.to_a).to contain_exactly('.gitignore', 'foo')
      end

      it "doesn't rescue the yielded block" do
        expect { subject.each { |x| File.read(x) }.to_a }.to raise_error(Errno::ENOENT)
      end
    end

    context 'with soft link loops' do
      before do
        create_file_list 'foo_target', '.gitignore'
        create_symlink('foo' => 'foo_target')
        FileUtils.rm('foo_target')
        create_symlink('foo_target' => 'foo')
      end

      it 'rescues errors in PathList methods', :aggregate_failures do
        expect(subject.include?('foo')).to be false
        expect(subject.match?('foo')).to be true
        expect(subject.to_a).to contain_exactly('.gitignore', 'foo', 'foo_target')
      end

      it "doesn't rescue the yielded block" do
        expect { subject.each { |x| File.read(x) }.to_a }.to raise_error(Errno::ELOOP)
      end
    end

    it 'treats soft links to directories as files rather than the directories they point to' do
      create_file_list 'foo_target/foo_child'
      gitignore 'foo_target'

      create_symlink('foo' => 'foo_target')
      expect(subject).to allow_exactly('foo', '.gitignore')
    end

    it 'matches soft links as their own paths not the paths they point to' do
      create_file_list 'foo_target'
      gitignore 'foo_target'

      create_symlink('foo' => 'foo_target')
      expect(subject).to allow_exactly('foo', '.gitignore')
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
    end

    describe 'with patterns in the higher level files being overridden by those in lower level files.' do
      before do
        create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d', 'a/b/e'
      end

      it 'respects rules overridden in child gitignore files' do
        gitignore '**/b/d', '**/b/c'
        gitignore '!b/d', '!b/e', 'b/c', path: 'a/.gitignore'
        gitignore 'd', '!c', path: 'a/b/.gitignore'

        # i want a new one each time
        expect(described_class.gitignore.include?('a/b/c')).to be true
        expect(described_class.gitignore.include?('a/b/e')).to be true
        expect(described_class.gitignore.include?('a/b/d')).to be false
        expect(described_class.gitignore.include?('b/d')).to be false
        expect(described_class.gitignore.include?('b/c')).to be false
      end
    end

    describe 'Patterns read from gitignore referred by gitconfig' do
      it 'recognises ~/.gitconfig gitignore files' do
        gitignore 'b/d'

        stub_file <<~GITCONFIG, path: "#{Dir.home}/.gitconfig"
          [core]
          \texcludesfile = ~/.global_gitignore
        GITCONFIG

        stub_file("a/b/c\n", path: "#{Dir.home}/.global_gitignore")

        expect(subject).not_to match_files('a/b/d', 'b/c')
        expect(subject).to match_files('a/b/c', 'b/d')
      end

      context 'when no global gitignore' do
        it 'recognises project subdir .gitignore file and no project dir gitignore' do
          gitignore ''
          gitignore '/b/c', path: 'a/.gitignore'
          gitignore 'd', path: 'b/.gitignore'

          expect(subject).not_to match_files('a/b/d', 'b/c')
          expect(subject).to match_files('a/b/c', 'b/d')
        end

        it 'recognises project subdir .gitignore file when one is empty when no project dir gitignore' do
          gitignore ''
          gitignore '#this is just a comment', path: 'a/.gitignore'
          gitignore '/d', path: 'a/b/.gitignore'

          expect(subject).not_to match_files('b/c', 'a/b/c', 'b/d')
          expect(subject).to match_files('a/b/d')
        end
      end
    end
  end

  describe 'query interface combinations' do
    it 'works for .gitignore and #only' do
      gitignore 'bar'
      create_file_list 'foo', 'bar', 'baz'

      gitignore_path_list = described_class.gitignore
      gitignore_only_path_list = gitignore_path_list.only(['bar', 'baz'])

      expect(gitignore_path_list).not_to allow_files('bar')
      expect(gitignore_path_list).to allow_files('baz', 'foo')
      expect(gitignore_path_list).not_to be gitignore_only_path_list

      expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_only_path_list).to allow_files('baz')
    end

    it 'works for .gitignore and #only!' do
      gitignore 'bar'

      gitignore_path_list = described_class.gitignore

      expect(gitignore_path_list).not_to allow_files('bar')
      expect(gitignore_path_list).to allow_files('baz', 'foo')

      gitignore_only_path_list = gitignore_path_list.only!(['bar', 'baz'])
      expect(gitignore_path_list).to be gitignore_only_path_list

      expect(gitignore_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_path_list).to allow_files('baz')

      expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_only_path_list).to allow_files('baz')
    end

    it 'works for .only and #gitignore' do
      gitignore 'bar'

      only_path_list = described_class.only(['bar', 'baz'])
      gitignore_only_path_list = only_path_list.gitignore

      expect(only_path_list).not_to allow_files('foo')
      expect(only_path_list).to allow_files('baz', 'bar')
      expect(only_path_list).not_to be gitignore_only_path_list

      expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_only_path_list).to allow_files('baz')
    end

    it 'works for .only and #gitignore!' do
      gitignore 'bar'

      only_path_list = described_class.only(['bar', 'baz'])

      expect(only_path_list).not_to allow_files('foo')
      expect(only_path_list).to allow_files('baz', 'bar')

      gitignore_only_path_list = only_path_list.gitignore!
      expect(only_path_list).to be gitignore_only_path_list

      expect(only_path_list).not_to allow_files('foo', 'bar')
      expect(only_path_list).to allow_files('baz')

      expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_only_path_list).to allow_files('baz')
    end

    it 'works for .ignore and #only' do
      ignore_path_list = described_class.ignore('bar')
      ignore_only_path_list = ignore_path_list.only(['bar', 'baz'])

      expect(ignore_path_list).not_to allow_files('bar')
      expect(ignore_path_list).to allow_files('baz', 'foo')
      expect(ignore_path_list).not_to be ignore_only_path_list

      expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(ignore_only_path_list).to allow_files('baz')
    end

    it 'works for .ignore and #only!' do
      ignore_path_list = described_class.ignore('bar')

      expect(ignore_path_list).not_to allow_files('bar')
      expect(ignore_path_list).to allow_files('baz', 'foo')

      ignore_only_path_list = ignore_path_list.only!(['bar', 'baz'])
      expect(ignore_path_list).to be ignore_only_path_list

      expect(ignore_path_list).not_to allow_files('foo', 'bar')
      expect(ignore_path_list).to allow_files('baz')

      expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(ignore_only_path_list).to allow_files('baz')
    end

    it 'works for .only and #ignore' do
      only_path_list = described_class.only(['bar', 'baz'])
      ignore_only_path_list = only_path_list.ignore('bar')

      expect(only_path_list).not_to allow_files('foo')
      expect(only_path_list).to allow_files('baz', 'bar')
      expect(only_path_list).not_to be ignore_only_path_list

      expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(ignore_only_path_list).to allow_files('baz')
    end

    it 'works for .only and #ignore!' do
      only_path_list = described_class.only(['bar', 'baz'])

      expect(only_path_list).not_to allow_files('foo')
      expect(only_path_list).to allow_files('baz', 'bar')

      ignore_only_path_list = only_path_list.ignore!('bar')
      expect(only_path_list).to be ignore_only_path_list

      expect(only_path_list).not_to allow_files('foo', 'bar')
      expect(only_path_list).to allow_files('baz')

      expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
      expect(ignore_only_path_list).to allow_files('baz')
    end

    it 'works for .gitignore and #ignore' do
      gitignore 'bar'

      gitignore_path_list = described_class.gitignore
      gitignore_ignore_path_list = gitignore_path_list.ignore(['foo'])

      expect(gitignore_path_list).not_to allow_files('bar')
      expect(gitignore_path_list).to allow_files('baz', 'foo')
      expect(gitignore_path_list).not_to be gitignore_ignore_path_list

      expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_ignore_path_list).to allow_files('baz')
    end

    it 'works for .gitignore and #ignore!' do
      gitignore 'bar'

      gitignore_path_list = described_class.gitignore

      expect(gitignore_path_list).not_to allow_files('bar')
      expect(gitignore_path_list).to allow_files('baz', 'foo')

      gitignore_ignore_path_list = gitignore_path_list.ignore!(['foo'])
      expect(gitignore_path_list).to be gitignore_ignore_path_list

      expect(gitignore_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_path_list).to allow_files('baz')

      expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_ignore_path_list).to allow_files('baz')
    end

    it 'works for .ignore and #gitignore' do
      gitignore 'bar'

      ignore_path_list = described_class.ignore(['foo'])
      gitignore_ignore_path_list = ignore_path_list.gitignore

      expect(ignore_path_list).not_to allow_files('foo')
      expect(ignore_path_list).to allow_files('baz', 'bar')
      expect(ignore_path_list).not_to be gitignore_ignore_path_list

      expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_ignore_path_list).to allow_files('baz')
    end

    it 'works for .ignore and #gitignore!' do
      gitignore 'bar'

      ignore_path_list = described_class.ignore(['foo'])

      expect(ignore_path_list).not_to allow_files('foo')
      expect(ignore_path_list).to allow_files('baz', 'bar')

      gitignore_ignore_path_list = ignore_path_list.gitignore!
      expect(ignore_path_list).to be gitignore_ignore_path_list

      expect(ignore_path_list).not_to allow_files('foo', 'bar')
      expect(ignore_path_list).to allow_files('baz')

      expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
      expect(gitignore_ignore_path_list).to allow_files('baz')
    end

    context 'when combined with .intersection' do
      it 'works for .gitignore and .only' do
        gitignore 'bar'

        gitignore_path_list = described_class.gitignore
        gitignore_only_path_list = gitignore_path_list.intersection(described_class.only(['bar', 'baz']))

        expect(gitignore_path_list).not_to allow_files('bar')
        expect(gitignore_path_list).to allow_files('baz', 'foo')
        expect(gitignore_path_list).not_to be gitignore_only_path_list

        expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_only_path_list).to allow_files('baz')
      end

      it 'works for .only and .gitignore' do
        gitignore 'bar'

        only_path_list = described_class.only(['bar', 'baz'])
        gitignore_only_path_list = only_path_list.intersection(described_class.gitignore)

        expect(only_path_list).not_to allow_files('foo')
        expect(only_path_list).to allow_files('baz', 'bar')
        expect(only_path_list).not_to be gitignore_only_path_list

        expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_only_path_list).to allow_files('baz')
      end

      it 'works for .ignore and .only' do
        ignore_path_list = described_class.ignore('bar')
        ignore_only_path_list = ignore_path_list.intersection(described_class.only(['bar', 'baz']))

        expect(ignore_path_list).not_to allow_files('bar')
        expect(ignore_path_list).to allow_files('baz', 'foo')
        expect(ignore_path_list).not_to be ignore_only_path_list

        expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(ignore_only_path_list).to allow_files('baz')
      end

      it 'works for .only and .ignore' do
        only_path_list = described_class.only(['bar', 'baz'])
        ignore_only_path_list = only_path_list.intersection(described_class.ignore('bar'))

        expect(only_path_list).not_to allow_files('foo')
        expect(only_path_list).to allow_files('baz', 'bar')
        expect(only_path_list).not_to be ignore_only_path_list

        expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(ignore_only_path_list).to allow_files('baz')
      end

      it 'works for .gitignore and .ignore' do
        gitignore 'bar'

        gitignore_path_list = described_class.gitignore
        gitignore_ignore_path_list = gitignore_path_list.intersection(described_class.ignore(['foo']))

        expect(gitignore_path_list).not_to allow_files('bar')
        expect(gitignore_path_list).to allow_files('baz', 'foo')
        expect(gitignore_path_list).not_to be gitignore_ignore_path_list

        expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_ignore_path_list).to allow_files('baz')
      end

      it 'works for .ignore and .gitignore' do
        gitignore 'bar'

        ignore_path_list = described_class.ignore(['foo'])
        gitignore_ignore_path_list = ignore_path_list.intersection(described_class.gitignore)

        expect(ignore_path_list).not_to allow_files('foo')
        expect(ignore_path_list).to allow_files('baz', 'bar')
        expect(ignore_path_list).not_to be gitignore_ignore_path_list

        expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_ignore_path_list).to allow_files('baz')
      end
    end

    context 'when combined with .intersection!' do
      it 'works for .gitignore and .only' do
        gitignore 'bar'

        gitignore_path_list = described_class.gitignore

        expect(gitignore_path_list).not_to allow_files('bar')
        expect(gitignore_path_list).to allow_files('baz', 'foo')

        gitignore_only_path_list = gitignore_path_list.intersection!(described_class.only(['bar', 'baz']))
        expect(gitignore_path_list).to be gitignore_only_path_list

        expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_only_path_list).to allow_files('baz')
      end

      it 'works for .only and .gitignore' do
        gitignore 'bar'

        only_path_list = described_class.only(['bar', 'baz'])

        expect(only_path_list).not_to allow_files('foo')
        expect(only_path_list).to allow_files('baz', 'bar')
        gitignore_only_path_list = only_path_list.intersection!(described_class.gitignore)
        expect(only_path_list).to be gitignore_only_path_list

        expect(gitignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_only_path_list).to allow_files('baz')
      end

      it 'works for .ignore and .only' do
        ignore_path_list = described_class.ignore('bar')

        expect(ignore_path_list).not_to allow_files('bar')
        expect(ignore_path_list).to allow_files('baz', 'foo')
        ignore_only_path_list = ignore_path_list.intersection!(described_class.only(['bar', 'baz']))
        expect(ignore_path_list).to be ignore_only_path_list

        expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(ignore_only_path_list).to allow_files('baz')
      end

      it 'works for .only and .ignore' do
        only_path_list = described_class.only(['bar', 'baz'])

        expect(only_path_list).not_to allow_files('foo')
        expect(only_path_list).to allow_files('baz', 'bar')
        ignore_only_path_list = only_path_list.intersection!(described_class.ignore('bar'))
        expect(only_path_list).to be ignore_only_path_list

        expect(ignore_only_path_list).not_to allow_files('foo', 'bar')
        expect(ignore_only_path_list).to allow_files('baz')
      end

      it 'works for .gitignore and .ignore' do
        gitignore 'bar'

        gitignore_path_list = described_class.gitignore

        expect(gitignore_path_list).not_to allow_files('bar')
        expect(gitignore_path_list).to allow_files('baz', 'foo')
        gitignore_ignore_path_list = gitignore_path_list.intersection!(described_class.ignore(['foo']))
        expect(gitignore_path_list).to be gitignore_ignore_path_list

        expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_ignore_path_list).to allow_files('baz')
      end

      it 'works for .ignore and .gitignore' do
        gitignore 'bar'

        ignore_path_list = described_class.ignore(['foo'])

        expect(ignore_path_list).not_to allow_files('foo')
        expect(ignore_path_list).to allow_files('baz', 'bar')
        gitignore_ignore_path_list = ignore_path_list.intersection!(described_class.gitignore)
        expect(ignore_path_list).to be gitignore_ignore_path_list

        expect(gitignore_ignore_path_list).not_to allow_files('foo', 'bar')
        expect(gitignore_ignore_path_list).to allow_files('baz')
      end
    end

    context 'when combined with .union' do
      it 'works for .gitignore and .only' do
        gitignore 'bar', 'foo'

        gitignore_path_list = described_class.gitignore
        gitignore_only_path_list = gitignore_path_list.union(described_class.only(['bar', 'baz']))

        expect(gitignore_path_list).not_to allow_files('bar', 'foo')
        expect(gitignore_path_list).to allow_files('baz')
        expect(gitignore_path_list).not_to be gitignore_only_path_list

        expect(gitignore_only_path_list).not_to allow_files('foo')
        expect(gitignore_only_path_list).to allow_files('bar', 'baz')
      end

      it 'works for .only and .gitignore' do
        gitignore 'bar', 'foo'

        only_path_list = described_class.only(['bar', 'baz'])
        gitignore_only_path_list = only_path_list.union(described_class.gitignore)

        expect(only_path_list).not_to allow_files('foo')
        expect(only_path_list).to allow_files('baz', 'bar')
        expect(only_path_list).not_to be gitignore_only_path_list

        expect(gitignore_only_path_list).not_to allow_files('foo')
        expect(gitignore_only_path_list).to allow_files('bar', 'baz')
      end

      it 'works for .ignore and .only' do
        ignore_path_list = described_class.ignore('bar', 'foo')
        ignore_only_path_list = ignore_path_list.union(described_class.only(['bar', 'baz']))

        expect(ignore_path_list).not_to allow_files('bar', 'foo')
        expect(ignore_path_list).to allow_files('baz')
        expect(ignore_path_list).not_to be ignore_only_path_list

        expect(ignore_only_path_list).not_to allow_files('foo')
        expect(ignore_only_path_list).to allow_files('bar', 'baz')
      end

      it 'works for .only and .ignore' do
        only_path_list = described_class.only(['bar', 'baz'])
        ignore_only_path_list = only_path_list.union(described_class.ignore('bar', 'foo'))

        expect(only_path_list).not_to allow_files('foo')
        expect(only_path_list).to allow_files('baz', 'bar')
        expect(only_path_list).not_to be ignore_only_path_list

        expect(ignore_only_path_list).not_to allow_files('foo')
        expect(ignore_only_path_list).to allow_files('bar', 'baz')
      end

      it 'works for .gitignore and .ignore' do
        gitignore 'bar', 'foo'

        gitignore_path_list = described_class.gitignore
        gitignore_ignore_path_list = gitignore_path_list.union(described_class.ignore(['foo', 'baz']))

        expect(gitignore_path_list).not_to allow_files('bar', 'bar')
        expect(gitignore_path_list).to allow_files('baz')
        expect(gitignore_path_list).not_to be gitignore_ignore_path_list

        expect(gitignore_ignore_path_list).not_to allow_files('foo')
        expect(gitignore_ignore_path_list).to allow_files('bar', 'baz')
      end

      it 'works for .ignore and .gitignore' do
        gitignore 'bar', 'foo'

        ignore_path_list = described_class.ignore(['foo', 'baz'])
        gitignore_ignore_path_list = ignore_path_list.union(described_class.gitignore)

        expect(ignore_path_list).not_to allow_files('foo', 'baz')
        expect(ignore_path_list).to allow_files('bar')
        expect(ignore_path_list).not_to be gitignore_ignore_path_list

        expect(gitignore_ignore_path_list).not_to allow_files('foo')
        expect(gitignore_ignore_path_list).to allow_files('bar', 'baz')
      end
    end
  end

  describe '.intersection' do
    it 'can combine with AND any number of path lists' do
      path_list = described_class.only('a', 'b', 'c')
      intersection_path_list = path_list.intersection(
        described_class.only('b', 'c', 'd'),
        described_class.only('a', 'b', 'd')
      )

      expect(path_list).to allow_files('a', 'b', 'c')
      expect(path_list).not_to allow_files('d')

      expect(intersection_path_list).to allow_files('b')
      expect(intersection_path_list).not_to allow_files('a', 'c', 'd')
    end
  end

  describe '&' do
    it 'can combine with AND one other path lists' do
      path_list = described_class.only('a', 'b', 'c')
      intersection_path_list = path_list & described_class.only('b', 'c', 'd')

      expect(path_list).to allow_files('a', 'b', 'c')
      expect(path_list).not_to allow_files('d')

      expect(intersection_path_list).to allow_files('b', 'c')
      expect(intersection_path_list).not_to allow_files('a', 'd', 'e')
    end
  end

  describe '.intersection!' do
    it 'can combine with AND any number of path lists, modifying the receiver' do
      path_list = described_class.only('a', 'b', 'c')
      expect(path_list).to allow_files('a', 'b', 'c')
      expect(path_list).not_to allow_files('d')

      intersection_path_list = path_list.intersection!(
        described_class.only('b', 'c', 'd'),
        described_class.only('a', 'b', 'd')
      )

      expect(path_list).to allow_files('b')
      expect(path_list).not_to allow_files('a', 'c', 'd')

      expect(intersection_path_list).to allow_files('b')
      expect(intersection_path_list).not_to allow_files('a', 'c', 'd')
    end
  end

  describe '.union' do
    it 'can combine with OR any number of path lists' do
      path_list = described_class.only('a', 'b', 'c')
      union_path_list = path_list.union(
        described_class.only('b', 'c', 'd'),
        described_class.only('a', 'e')
      )

      expect(path_list).to allow_files('a', 'b', 'c')
      expect(path_list).not_to allow_files('d')

      expect(union_path_list).to allow_files('a', 'b', 'c', 'd', 'e')
      expect(union_path_list).not_to allow_files('f', 'g', 'h')
    end
  end

  describe '|' do
    it 'can combine with OR one of path lists' do
      path_list = described_class.only('a', 'b', 'c')
      union_path_list = path_list | described_class.only('b', 'c', 'd')

      expect(path_list).to allow_files('a', 'b', 'c')
      expect(path_list).not_to allow_files('d')

      expect(union_path_list).to allow_files('a', 'b', 'c', 'd')
      expect(union_path_list).not_to allow_files('e', 'f', 'g', 'h')
    end
  end

  describe '.union!' do
    it 'can combine with AND any number of path lists, modifying the receiver' do
      path_list = described_class.only('a', 'b', 'c')

      expect(path_list).to allow_files('a', 'b', 'c')
      expect(path_list).not_to allow_files('d')

      union_path_list = path_list.union!(
        described_class.only('b', 'c', 'd'),
        described_class.only('a', 'e')
      )

      expect(path_list).to allow_files('a', 'b', 'c', 'd', 'e')
      expect(path_list).not_to allow_files('f', 'g', 'h')

      expect(union_path_list).to allow_files('a', 'b', 'c', 'd', 'e')
      expect(union_path_list).not_to allow_files('f', 'g', 'h')
    end
  end

  describe '.only' do
    context 'with blank only value' do
      subject(:path_list) { described_class.only([]) }

      it 'returns all files' do
        create_file_list 'foo', 'bar'
        expect(subject).to allow_exactly('foo', 'bar')
      end
    end

    context 'with missing only read_from_file value' do
      subject(:path_list) { described_class.only(read_from_file: './nonsense') }

      it 'returns all files' do
        create_file_list 'foo', 'bar'
        expect(subject).to allow_exactly('foo', 'bar')
      end
    end

    context 'with subdir includes file' do
      subject(:path_list) { described_class.only(read_from_file: 'a/.includes_file') }

      it 'recognises subdir includes file' do
        create_file '/b/d', 'c', path: 'a/.includes_file'

        expect(subject).to allow_files('a/c', 'a/b/d', 'a/b/c')
        expect(subject).not_to allow_files('b/c', 'b/d', 'a/b/e')
      end
    end

    context 'with an unanchored include' do
      subject(:path_list) { described_class.only('**/b') }

      it '#match? matches directories implicitly', :aggregate_failures do
        create_file_list 'a/b', 'b/a'

        expect(subject.match?('a/')).to be true
        expect(subject.match?('b/')).to be true
        expect(subject.match?(Pathname.pwd.dirname)).to be true
      end
    end

    context 'with an anchored include' do
      subject(:path_list) { described_class.only('a/b') }

      it "#match? doesn't match directories implicitly", :aggregate_failures do
        create_file_list 'a/b', 'b/a'

        expect(subject.match?('a')).to be true
        expect(subject.match?('b')).to be false
        expect(subject.match?('c')).to be false
        expect(subject.match?('a/b/c')).to be true
        expect(subject.include?('a/b')).to be true
        expect(subject.include?('a/b/c')).to be false
        expect(subject.include?('b/a')).to be false
        expect(subject.match?(Pathname.pwd.dirname)).to be true
      end
    end

    context 'with an unanchored include, preceded by an explicit negation' do
      subject(:path_list) { described_class.only(['!a', '**/b']) }

      it '#include? defers matching implicitly' do
        create_file_list 'a/b', 'b/a', 'b/c', 'c/b'

        expect(subject).to allow_exactly('b/c', 'c/b')
      end
    end

    context 'with negation, preceded by an explicit include' do
      subject(:path_list) { described_class.only(['**/b', '!a']) }

      it '#include? defers matching implicitly' do
        create_file_list 'a/b', 'b/a', 'b/c', 'c/b'

        expect(subject).to allow_exactly('b/c', 'c/b')
      end
    end

    context 'when given an array of include and gitignore' do
      subject(:path_list) { described_class.gitignore.only(['bar', 'baz']) }

      it 'reads the list of rules and gitignore' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end

      it 'responds to to_proc shenanigans' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore 'bar'

        expect(['foo', 'bar', 'baz'].map(&subject)).to eq [false, false, true]
      end
    end

    context 'when given an array of include_rules as symbols and gitignore' do
      subject(:path_list) { described_class.gitignore.only(:bar, :baz) }

      it 'reads the list of rules and gitignore' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given a small array of include_rules and gitignore' do
      subject(:path_list) { described_class.gitignore.only(['bar']) }

      it 'reads the list of rules and gitignore' do
        gitignore 'foo'

        expect(subject).not_to allow_files('foo/bar')
        expect(subject).to allow_files('baz/bar')
      end
    end

    context 'when given an array of include_rules beginning with `/` and gitignore' do
      subject(:path_list) { described_class.gitignore.only('/bar', '/baz') }

      it 'reads the list of rules and gitignore' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo/bar/foo', 'foo/bar/baz', 'bar/foo')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given an array of include_rules ending with `/` and gitignore' do
      subject(:path_list) { described_class.gitignore.only('bar/', 'baz/') }

      it 'reads the list of rules and gitignore' do
        gitignore 'bar'

        expect(subject).not_to allow_files('baz', 'foo/bar/baz', 'bar/foo')
        expect(subject).to allow_files('foo/baz/foo')
      end
    end

    context 'when given an array of include_rules with `!` and gitignore' do
      subject(:path_list) { described_class.gitignore.only('fo*', '!foo', 'food') }

      it 'reads the list of rules and gitignore' do
        gitignore 'for'

        expect(subject).not_to allow_files('foo', 'for')
        expect(subject).to allow_files('foe', 'food')
      end
    end

    context 'when given an array of argv_rules with absolute paths and gitignore' do
      subject(:path_list) { described_class.gitignore.only(['./bar', "#{Dir.pwd}/baz"], format: :glob) }

      it 'resolves the paths to the current directory' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given an argv rule with an unexpandable user path' do
      subject(:path_list) { described_class.only('~not-a-user635728345/foo', format: :glob) }

      it 'treats it as literal' do
        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('~not-a-user635728345/foo')
      end
    end

    context 'when given an array of negated argv_rules with absolute paths and gitignore' do
      subject(:path_list) { described_class.gitignore.only(['*', '!./foo', "!#{Dir.pwd}/baz"], format: :glob) }

      it 'resolves the paths even when negated' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'baz', 'bar')
        expect(subject).to allow_files('boo')
      end
    end

    context 'when given an array of unanchored argv_rules' do
      subject(:path_list) { described_class.only(['**/foo', '*baz'], format: :glob) }

      it 'treats the rules as unanchored' do
        expect(subject).not_to allow_files('bar/bar')
        expect(subject).to allow_files('bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz')
      end
    end

    context 'when given an argv_rules with ending /' do
      subject(:path_list) { described_class.only(['./foo/'], format: :glob) }

      it 'treats the rule as dir only' do
        expect(subject).not_to allow_files('bar/foo')
        expect(subject).to allow_files('foo/bar')
      end
    end

    context 'when given an array of anchored argv_rules with absolute paths and gitignore' do
      subject(:path_list) { described_class.only(['foo', 'baz'], format: :glob) }

      it 'anchors the rules to the given dir, for performance reasons' do
        expect(subject).not_to allow_files('bar/foo', 'bar/baz')
        expect(subject).to allow_files('foo', 'baz/foo', 'baz/baz')
      end
    end

    context 'when given an array of argv_rules and include_rules' do
      subject(:path_list) { described_class.only(['foo', 'baz']).only('foo', 'bar', format: :glob) }

      it 'adds the rulesets, they must pass both lists' do
        expect(subject).not_to allow_files('baz', 'bar')
        expect(subject).to allow_files('foo')
      end
    end

    context 'when given shebang and path rules with .union' do
      subject(:path_list) do
        described_class.only(['*.rb', 'Rakefile']).union(described_class.only('ruby', format: :shebang)).gitignore
      end

      it 'matches files based on either the pathname or the format' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'sub/foo'
          #!/usr/bin/env ruby -w --disable-gems --verbose --enable-frozen-string-literal

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'ignored_foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: '.simplecov'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'ignored_bar/ruby.rb'
          puts('ok')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file <<~RUBY, path: 'Rakefile'
          puts "ok"
        RUBY

        create_file_list 'baz', 'baz.rb'

        gitignore 'ignored_foo', 'ignored_bar'

        expect(subject).to allow_files('sub/foo', 'foo', 'baz.rb', 'Rakefile')
        expect(subject).not_to allow_files(
          'ignored_foo', 'bar', 'baz', 'ignored_bar/ruby.rb', 'nonexistent/file', '.simplecov'
        )
      end
    end

    context 'when given include shebang rule scoped by a file' do
      subject(:path_list) { described_class.only(read_from_file: 'a/.include', format: :shebang) }

      it 'matches files with or sub to that directory' do
        create_file <<~RUBY, path: 'a/foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'a/bar'
          #!/usr/bin/env bash

          echo 'ok'
        BASH

        create_file <<~RUBY, path: 'a/b/foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby

          puts('no')
        RUBY

        create_file 'ruby', path: 'a/.include'

        expect(subject).not_to allow_files('foo', 'a/bar')
        expect(subject).to allow_files('a/foo', 'a/b/foo')
      end
    end

    context 'with shebang args with gitignore' do
      subject(:path_list) { described_class.gitignore.only('ruby', format: :shebang) }

      it "matches files with that shebang that aren't ignored for other reasons" do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'sub/foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'ignored_foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'ignored_bar/ruby'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore 'ignored_bar', 'ignored_foo'

        expect(subject).to allow_files('sub/foo', 'foo')
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb', 'ignored_bar/ruby')
      end
    end

    context 'with shebang args' do
      subject(:path_list) { described_class.only('ruby', format: :shebang) }

      it 'matches files with that shebang' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        expect(subject).to allow_files('foo')
        expect(subject).not_to allow_files('bar', 'baz', 'baz.rb')
      end

      it 'uses content given to match?, ignoring the actual content' do
        actual_content = <<~BASH
          #!/usr/bin/env bash

          echo 'ok'
        BASH

        fake_content = <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file actual_content, path: 'foo'

        expect(subject.include?('foo')).to be false
        expect(subject.match?('foo', content: fake_content)).to be true
      end
    end

    context 'with full-name shebang args' do
      subject(:path_list) { described_class.only('#!/usr/bin/env ruby', format: :shebang) }

      it 'matches files with that shebang' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        expect(subject).to allow_files('foo')
        expect(subject).not_to allow_files('bar', 'baz', 'baz.rb')
      end
    end

    context 'with shebang args and root down a level' do
      subject(:path_list) { described_class.only('ruby', root: 'sub', format: :shebang) }

      it 'matches files based on each shebang within the child directory' do
        create_file <<~RUBY, path: 'sub/foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'sub/bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        expect(subject).to allow_files('sub/foo')
        expect(subject).not_to allow_files('foo', 'sub/bar')
      end
    end

    context 'with shebang args with root up a level' do
      subject(:path_list) { described_class.gitignore.only('ruby', root: '../', format: :shebang) }

      it 'matches files based on each shebang within the current directory' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'ignored_foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore 'ignored_foo'

        expect(subject).to allow_files('foo')
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb')
      end
    end

    context 'with shebang args as a string list' do
      subject(:path_list) { described_class.gitignore.only("ruby\nbash", format: :shebang) }

      it 'matches files based on each shebang' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'ignored_foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore 'ignored_foo'

        expect(subject).to allow_files('foo', 'bar')
        expect(subject).not_to allow_files('ignored_foo', 'baz', 'baz.rb')
      end
    end
  end

  describe '.ignore' do
    context 'when given a file other than gitignore' do
      subject(:path_list) { described_class.ignore(read_from_file: 'fancyignore') }

      it 'ignores files based on the non-gitignore file' do
        gitignore 'bar'
        create_file 'foo', path: 'fancyignore'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar', 'baz')
      end
    end

    context 'when given a file including gitignore' do
      subject(:path_list) { described_class.gitignore.ignore(read_from_file: 'fancyignore') }

      it 'ignores files based on the non-gitignore file and the gitignore file' do
        gitignore 'bar'
        create_file 'foo', path: 'fancyignore'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given ignore rules' do
      subject(:path_list) { described_class.ignore('foo') }

      it 'ignores files based on the list of rules' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar', 'baz')
      end
    end

    context 'when given ignore rules and gitignore' do
      subject(:path_list) { described_class.gitignore.ignore('foo') }

      it 'ignores files based on the list of rules and gitignore' do
        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'with denied a directory' do
      subject(:path_list) { described_class.ignore('a/') }

      it "doesn't cache dirs as non dirs" do
        expect(subject.match?('a', directory: false)).to be true
        expect(subject.match?('a/b', directory: false)).to be false
      end
    end

    context 'when given ignore shebang rule scoped by a file' do
      subject(:path_list) { described_class.ignore(read_from_file: 'a/.ignore', format: :shebang) }

      it 'matches based on the file directory' do
        create_file <<~RUBY, path: 'a/foo'
          #!/usr/bin/env ruby -w

          puts('no')
        RUBY

        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby

          puts('ok')
        RUBY

        create_file 'ruby', 'bash', path: 'a/.ignore'

        expect(subject).not_to allow_files('a/foo')
        expect(subject).to allow_files('foo')
      end
    end

    context 'when given an array of shebang ignore rules' do
      subject(:path_list) do
        described_class.ignore(['ruby'], format: :shebang)
      end

      it 'matches based on the shebang' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('no')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo ok
        BASH

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar')
      end
    end

    context 'when given UPPERCASE shebang ignore rule' do
      subject(:path_list) do
        described_class.ignore('RUBY', format: :shebang)
      end

      it 'matches regardless of case' do
        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby -w

          puts('no')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/usr/bin/env bash

          echo ok
        BASH

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar')
      end
    end

    context "when given lowercase shebang ignore rule with uppercase shebang (I don't know your life)" do
      subject(:path_list) do
        described_class.ignore('ruby', format: :shebang)
      end

      it 'matches regardless of case' do
        create_file <<~RUBY, path: 'foo'
          #!/USR/BIN/ENV RUBY

          puts('no')
        RUBY

        create_file <<~BASH, path: 'bar'
          #!/USR/BIN/ENV BASH

          echo ok
        BASH

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar')
      end
    end
  end
end
