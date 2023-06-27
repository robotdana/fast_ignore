# frozen_string_literal: true

require 'pathname'

RSpec.describe PathList do
  let(:git_init) { false }

  around { |e| within_temp_dir(git_init: git_init) { e.run } }

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

    it 'can be shortcut with directory:' do
      create_file_list 'a'
      expect(subject.include?('a', directory: false)).to be true
    end

    it 'returns false for a directory by default' do
      create_file_list 'a'
      expect(subject.include?('a', directory: true)).to be false
    end

    it 'can be lied to with directory: false' do
      create_file_list 'a/b'
      expect(subject.include?('a', directory: false)).to be true
    end

    it 'can be lied to with directory: true' do
      create_file_list 'a/b'
      expect(subject.include?('a/b', directory: true)).to be false
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

    it 'can be allowed with with a non-dir' do
      create_file_list 'a'
      expect(subject.match?('a', exists: true, directory: false)).to be true
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
          PathList::Matchers::PathRegexp.new(%r{\A#{Regexp.escape(Dir.pwd).downcase}(?:/|\z)}, :allow),
          PathList::Matchers::Mutable.new(
            PathList::Matchers::PathRegexp.new(%r{\A#{Regexp.escape(Dir.pwd).downcase}/(?:.*/)?(?:foo\z|bar\z)}, :ignore)
          )
        ),
        PathList::Matchers::PathRegexp.new(%r{/\.git\z}, :ignore)
      ])

      expect(subject.send(:file_matcher)).to be_like PathList::Matchers::LastMatch.new([
        PathList::Matchers::Allow,
        PathList::Matchers::Mutable.new(
          PathList::Matchers::PathRegexp.new(%r{\A#{Regexp.escape(Dir.pwd).downcase}/(?:.*/)?foo\z}, :ignore)
        ),
        PathList::Matchers::PathRegexp.new(%r{/\.git\z}, :ignore)
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

    it 'rescues soft links to nowhere' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')
      FileUtils.rm('foo_target')

      expect(subject.include?('foo')).to be false
      expect(subject.include?('foo', directory: true)).to be false
      expect(subject.select { |x| File.read(x) }.to_a).to contain_exactly('.gitignore')
    end

    it 'rescues soft link loops' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')
      FileUtils.rm('foo_target')
      create_symlink('foo_target' => 'foo')

      expect(subject.include?('foo')).to be false
      expect(subject.include?('foo', directory: true)).to be false
      expect(subject.select { |x| File.read(x) }.to_a).to contain_exactly('.gitignore')
    end

    it 'allows soft links to directories' do
      create_file_list 'foo_target/foo_child', '.gitignore'
      gitignore 'foo_target'

      create_symlink('foo' => 'foo_target')
      expect(subject).to allow_exactly('foo', '.gitignore')
    end

    it 'allows soft links' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')

      expect(subject).to allow_exactly('foo', 'foo_target', '.gitignore')
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
    end

    context 'with a .git/index' do
      let(:git_init) { true }

      it 'reads the gitignore' do
        gitignore 'foo', 'bar'

        create_file_list 'foo', 'bar', 'baz'

        expect(subject).to allow_files('baz')
        expect(subject).not_to allow_files('foo', 'bar')
      end

      context 'with additional only going on' do
        subject(:path_list) { described_class.gitignore.only('bar', 'foo') }

        it 'only shows those that pass both gitignore and only' do
          gitignore 'foo'

          create_file_list 'foo/bar', 'bar/child', 'baz/child'

          expect(subject).to allow_files('bar/child')
          expect(subject).not_to allow_files('foo/child', 'baz/child')
        end
      end

      context 'with additional ignore going on' do
        subject(:path_list) { described_class.gitignore.ignore('bar') }

        it 'only shows those that pass both gitignore and ignore' do
          gitignore 'foo'

          create_file_list 'foo/bar', 'bar/child', 'baz/child'

          expect(subject).to allow_files('baz/child')
          expect(subject).not_to allow_files('foo/child', 'bar/child')
        end

        it 'can allow untracked files' do # may need to use --untracked-cache ...?
          gitignore 'foo'

          create_file_list 'foo/bar', 'bar/child', 'baz/child', git_add: false

          expect(subject).to allow_files('baz/child', '.gitignore')
          expect(subject).not_to allow_files('foo/child', 'bar/child')
        end
      end
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
      before do
        gitignore 'b/d'
      end

      it 'recognises ~/.gitconfig gitignore files' do
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

          expect(subject).not_to match_files('b/c', 'a/b/c', 'b/d', 'b/d')
          expect(subject).to match_files('a/b/d')
        end
      end
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

    context 'with missing only from_file value' do
      subject(:path_list) { described_class.only(from_file: './nonsense') }

      it 'returns all files' do
        create_file_list 'foo', 'bar'
        expect(subject).to allow_exactly('foo', 'bar')
      end
    end

    context 'with subdir includes file' do
      subject(:path_list) { described_class.only(from_file: 'a/.includes_file') }

      it 'recognises subdir includes file' do
        create_file '/b/d', 'c', path: 'a/.includes_file'

        expect(subject).to allow_files('a/c', 'a/b/d', 'a/b/c')
        expect(subject).not_to allow_files('b/c', 'b/d', 'a/b/e')
      end
    end

    context 'with an unanchored include' do
      subject(:path_list) { described_class.only('**/b') }

      it "#match? doesn't match directories implicitly", :aggregate_failures do
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
        expect(subject.include?('a/b')).to be true
        expect(subject.include?('a/b/c', exists: true)).to be true
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

    context 'when given shebang and path rules with .any' do
      subject(:path_list) do
        described_class.gitignore.any(
          described_class.only(['*.rb', 'Rakefile']),
          described_class.only('ruby', format: :shebang)
        )
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

        expect(subject).to allow_files('sub/foo', 'foo', 'baz.rb', 'Rakefile', create: false)
        expect(subject).not_to allow_files(
          'ignored_foo', 'bar', 'baz', 'ignored_bar/ruby.rb', 'nonexistent/file', '.simplecov',
          create: false
        )
      end
    end

    context 'when given include shebang rule scoped by a file' do
      subject(:path_list) { described_class.only(from_file: 'a/.include', format: :shebang) }

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

        expect(subject).not_to allow_files('foo', 'a/bar', create: false)
        expect(subject).to allow_files('a/foo', 'a/b/foo', create: false)
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

        expect(subject).to allow_files('sub/foo', 'foo', create: false)
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb', 'ignored_bar/ruby', create: false)
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

        expect(subject).to allow_files('foo', create: false)
        expect(subject).not_to allow_files('bar', 'baz', 'baz.rb', create: false)
      end

      it 'uses content given to include?, ignoring the actual content' do
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
        expect(subject.include?('foo', content: fake_content)).to be true
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

        expect(subject).to allow_files('foo', create: false)
        expect(subject).not_to allow_files('bar', 'baz', 'baz.rb', create: false)
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

        expect(subject).to allow_files('sub/foo', create: false)
        expect(subject).not_to allow_files('foo', 'sub/bar', create: false)
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

        expect(subject).to allow_files('foo', create: false)
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb', create: false)
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

        expect(subject).to allow_files('foo', 'bar', create: false)
        expect(subject).not_to allow_files('ignored_foo', 'baz', 'baz.rb', create: false)
      end
    end
  end

  describe '.ignore' do
    context 'when given a file other than gitignore' do
      subject(:path_list) { described_class.ignore(from_file: 'fancyignore') }

      it 'ignores files based on the non-gitignore file' do
        gitignore 'bar'
        create_file 'foo', path: 'fancyignore'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar', 'baz')
      end
    end

    context 'when given a file including gitignore' do
      subject(:path_list) { described_class.gitignore.ignore(from_file: 'fancyignore') }

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
        expect(subject.include?('a', directory: false, exists: true)).to be true
        expect(subject.include?('a/b', directory: false, exists: true)).to be false
      end
    end

    context 'when given ignore shebang rule scoped by a file' do
      subject(:path_list) { described_class.ignore(from_file: 'a/.ignore', format: :shebang) }

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

        expect(subject).not_to allow_files('a/foo', create: false)
        expect(subject).to allow_files('foo', create: false)
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

        expect(subject).not_to allow_files('foo', create: false)
        expect(subject).to allow_files('bar', create: false)
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

        expect(subject).not_to allow_files('foo', create: false)
        expect(subject).to allow_files('bar', create: false)
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

        expect(subject).not_to allow_files('foo', create: false)
        expect(subject).to allow_files('bar', create: false)
      end
    end
  end
end
