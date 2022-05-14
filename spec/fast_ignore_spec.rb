# frozen_string_literal: true

require 'pathname'

RSpec.describe FastIgnore do
  it 'has a version number' do
    expect(FastIgnore::VERSION).not_to be nil
  end

  describe '.new' do
    subject { described_class.new(relative: true, **args) }

    let(:args) { {} }

    around { |e| within_temp_dir { e.run } }

    it 'returns all files when there is no gitignore' do
      create_file_list 'foo', 'bar'

      expect(subject).to allow_exactly('foo', 'bar')
    end

    describe 'gitignore: false' do
      let(:args) { { gitignore: false } }

      it 'returns all files when there is no gitignore' do
        create_file_list 'foo', 'bar'
        expect(subject).to allow_exactly('foo', 'bar')
      end

      it 'ignores the given gitignore file and returns all files anyway' do
        create_file_list 'foo', 'bar'

        gitignore 'foo', 'bar'

        expect(subject).to allow_files('foo', 'bar')
      end
    end

    it 'matches uppercase paths to lowercase patterns' do
      create_file_list 'FOO'
      gitignore 'foo'

      expect(subject).to match_files('FOO')
    end

    it 'matches lowercase paths to uppercase patterns' do
      create_file_list 'foo'
      gitignore 'FOO'

      expect(subject).to match_files('foo')
    end

    describe 'Patterns read from gitignore referred by gitconfig' do
      before do
        create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d'

        gitignore 'b/d'
      end

      it 'recognises ~/.gitconfig gitignore files' do
        stub_file(<<~GITCONFIG, path: "#{ENV['HOME']}/.gitconfig")
          [core]
          \texcludesfile = ~/.global_gitignore
        GITCONFIG

        stub_file("a/b/c\n", path: "#{ENV['HOME']}/.global_gitignore")

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

    context 'with subdir includes file' do
      before { create_file_list 'a/b/c', 'a/b/d', 'a/b/e', 'b/c', 'b/d', 'a/c' }

      let(:args) { { gitignore: false, include_files: ['a/.includes_file'] } }

      it 'recognises subdir includes file' do
        create_file '/b/d', 'c', path: 'a/.includes_file'

        expect(subject).to allow_files('a/c', 'a/b/d', 'a/b/c')
        expect(subject).not_to allow_files('b/c', 'b/d', 'a/b/e')
      end
    end

    context 'when ignore_files is outside root' do
      let(:args) { { root: 'a', ignore_files: '../.gitignore' } }

      it 'copes fine' do
        gitignore 'a/b'
        create_file_list 'a/b', 'b/c', 'a/d'
        expect(subject).not_to match_files('d')
        expect(subject).to match_files('b')
      end
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
    end

    it '#allowed? returns false nonexistent files' do
      expect(subject.allowed?('utter/nonsense')).to be false
    end

    it '#allowed? can be shortcut with directory:' do
      create_file_list 'a'
      expect(subject.allowed?('a', directory: false)).to be true
    end

    it '#allowed? returns false for a directory by default' do
      create_file_list 'a'
      expect(subject.allowed?('a', directory: true)).to be false
    end

    it '#allowed? can be lied to with directory:' do
      create_file_list 'a/b'
      expect(subject.allowed?('a', directory: false)).to be true
    end

    it '#allowed? can be allowed with include_directories: true' do
      create_file_list 'a/b'
      expect(subject.allowed?('a', include_directories: true)).to be true
    end

    it '#allowed? can be allowed with include_directories: true with trailing slash' do
      create_file_list 'a/b'
      expect(subject.allowed?('a/', include_directories: true)).to be true
    end

    it "#allowed? won't be confused by caching dirs as non dirs" do
      gitignore 'a/'

      expect(subject.allowed?('a', exists: true)).to be true
      expect(subject.allowed?('a/b', exists: true)).to be false
    end

    context 'with gitignore: false' do
      let(:args) { { gitignore: false } }

      it 'returns hidden files' do
        create_file_list '.gitignore', '.a', '.b/.c'

        expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
      end

      it '#allowed? returns false nonexistent files' do
        expect(subject.allowed?('utter/nonsense')).to be false
      end

      it '#allowed? can be shortcut with directory:' do
        create_file_list 'a'
        expect(subject.allowed?('a', directory: false)).to be true
      end

      it '#allowed? can be lied to with directory: false' do
        create_file_list 'a/b'
        expect(subject.allowed?('a', directory: false)).to be true
      end

      it '#allowed? can be lied to with directory: true' do
        create_file_list 'a/b'
        expect(subject.allowed?('a/b', directory: true)).to be false
      end

      it '#allowed? can be allowed with include_directories: true' do
        create_file_list 'a/b'
        expect(subject.allowed?('a', include_directories: true)).to be true
      end

      it '#allowed? can be allowed with include_directories: true with trailing slash' do
        create_file_list 'a/b'
        expect(subject.allowed?('a/', include_directories: true)).to be true
      end

      it '#allowed? can be allowed with include_directories: true with a non-dir' do
        create_file_list 'a'
        expect(subject.allowed?('a', exists: true, directory: false, include_directories: true)).to be true
      end

      context 'with denied a directory' do
        let(:args) { { gitignore: false, ignore_rules: 'a/' } }

        it "#allowed? won't be confused by caching dirs as non dirs" do
          expect(subject.allowed?('a', exists: true)).to be true
          expect(subject.allowed?('a/b', exists: true)).to be false
        end
      end
    end

    it 'rescues soft links to nowhere' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')
      FileUtils.rm('foo_target')

      expect(subject).not_to be_allowed('foo')
      expect(subject).not_to be_allowed('foo', directory: true)
      expect(subject.select { |x| File.read(x) }.to_a).to contain_exactly('.gitignore')
    end

    it 'rescues soft link loops' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')
      FileUtils.rm('foo_target')
      create_symlink('foo_target' => 'foo')

      expect(subject).not_to be_allowed('foo')
      expect(subject).not_to be_allowed('foo', directory: true)
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

    context 'when gitignore: false' do
      let(:args) { { gitignore: false, ignore_files: '.gitignore' } }

      it 'rescues soft links to nowhere' do
        create_file_list 'foo_target', '.gitignore'
        create_symlink('foo' => 'foo_target')
        FileUtils.rm('foo_target')

        expect(subject).not_to be_allowed('foo')
        expect(subject).not_to be_allowed('foo', directory: true)
        expect(subject.select { |x| File.read(x) }.to_a).to contain_exactly('.gitignore')
      end

      it 'rescues soft link loops' do
        create_file_list 'foo_target', '.gitignore'
        create_symlink('foo' => 'foo_target')
        FileUtils.rm('foo_target')
        create_symlink('foo_target' => 'foo')

        expect(subject).not_to be_allowed('foo')
        expect(subject).not_to be_allowed('foo', directory: true)
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
    end

    context 'when given a file other than gitignore' do
      let(:args) { { gitignore: false, ignore_files: File.join(Dir.pwd, 'fancyignore') } }

      it 'reads the non-gitignore file' do
        create_file_list 'foo', 'bar', 'baz'
        gitignore 'bar'
        create_file 'foo', path: 'fancyignore'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar', 'baz')
      end
    end

    context 'when given a file including gitignore' do
      let(:args) { { ignore_files: File.join(Dir.pwd, 'fancyignore') } }

      it 'reads the non-gitignore file and the gitignore file' do
        create_file_list 'foo', 'bar', 'baz'
        gitignore 'bar'
        create_file 'foo', path: 'fancyignore'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given an array of ignore_rules' do
      let(:args) { { gitignore: false, ignore_rules: 'foo' } }

      it 'reads the list of rules' do
        create_file_list 'foo', 'bar', 'baz'
        gitignore 'bar'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('bar', 'baz')
      end
    end

    context 'when given an array of ignore_rules and gitignore' do
      let(:args) { { ignore_rules: 'foo' } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar', 'baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

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
      let(:args) { { include_rules: [:bar, :baz] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given a small array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar', 'baz/bar'

        gitignore 'foo'

        expect(subject).not_to allow_files('foo/bar')
        expect(subject).to allow_files('baz/bar')
      end
    end

    context 'when given an array of include_rules beginning with `/` and gitignore' do
      let(:args) { { include_rules: ['/bar', '/baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore 'bar'

        expect(subject).not_to allow_files('foo/bar/foo', 'foo/bar/baz', 'bar/foo')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given an array of include_rules ending with `/` and gitignore' do
      let(:args) { { include_rules: ['bar/', 'baz/'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/baz/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore 'bar'

        expect(subject).not_to allow_files('baz', 'foo/bar/baz', 'bar/foo')
        expect(subject).to allow_files('foo/baz/foo')
      end
    end

    context 'when given an array of include_rules with `!` and gitignore' do
      let(:args) { { include_rules: ['fo*', '!foo', 'food'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'food', 'foe', 'for'

        gitignore 'for'

        expect(subject).not_to allow_files('foo', 'for')
        expect(subject).to allow_files('foe', 'food')
      end
    end

    context 'when given an array of argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['./bar', "#{Dir.pwd}/baz"] } }

      it 'resolves the paths to the current directory' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'bar')
        expect(subject).to allow_files('baz')
      end
    end

    context 'when given an argv rule with an unexpandable user path' do
      let(:args) { { argv_rules: '~not-a-user635728345/foo' } }

      it 'treats it as literal' do
        create_file_list 'foo', './~not-a-user635728345/foo'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('~not-a-user635728345/foo')
      end
    end

    context 'when given an array of negated argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['*', '!./foo', "!#{Dir.pwd}/baz"] } }

      it 'resolves the paths even when negated' do
        create_file_list 'foo', 'bar', 'baz', 'boo'

        gitignore 'bar'

        expect(subject).not_to allow_files('foo', 'baz', 'bar')
        expect(subject).to allow_files('boo')
      end
    end

    context 'when given an array of unanchored argv_rules' do
      let(:args) { { argv_rules: ['**/foo', '*baz'] } }

      it 'treats the rules as unanchored' do
        create_file_list 'bar/foo', 'bar/baz', 'bar/bar', 'foo', 'baz/foo', 'baz/baz'

        expect(subject).not_to allow_files('bar/bar', 'baz', 'bar')
        expect(subject).to allow_files('bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz')
      end
    end

    context 'when given an argv_rules with ending /' do
      let(:args) { { argv_rules: ['./foo/'] } }

      it 'treats the rule as dir only' do
        create_file_list 'foo/bar', 'bar/foo'

        expect(subject).not_to allow_files('bar/foo')
        expect(subject).to allow_files('foo/bar')
      end
    end

    context 'when given an array of anchored argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['foo', 'baz'] } }

      it 'anchors the rules to the given dir, for performance reasons' do
        create_file_list 'bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz'

        expect(subject).not_to allow_files('bar/foo', 'bar/baz')
        expect(subject).to allow_files('foo', 'baz/foo', 'baz/baz')
      end
    end

    context 'when given root as a child dir' do
      let(:args) { { root: Dir.pwd + '/bar' } }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'

        expect(subject).to allow_exactly('foo', 'baz')
      end
    end

    context 'when given root as a parent dir' do
      let(:args) { { root: '../' } }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'
        gitignore 'baz'

        Dir.chdir('bar') do
          expect(subject).to allow_exactly('bar/foo', 'fez', '.gitignore')
        end
      end
    end

    context 'when given root with a trailing slash' do
      let(:args) { { root: Dir.pwd + '/bar/' } }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'

        expect(subject).to allow_exactly('foo', 'baz')
      end
    end

    context 'when given root as a child dir and relative false' do
      let(:args) { { root: Dir.pwd + '/bar', relative: false } }

      it 'returns relative to the root' do
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'

        expect(subject).to allow_exactly(Dir.pwd + '/bar/foo', Dir.pwd + '/bar/baz')
      end
    end

    context 'when given an array of argv_rules and include_rules' do
      let(:args) { { argv_rules: ['foo', 'baz'], include_rules: ['foo', 'bar'] } }

      it 'adds the rulesets, they must pass both lists' do
        create_file_list 'foo', 'bar', 'baz'

        expect(subject).not_to allow_files('baz', 'bar')
        expect(subject).to allow_files('foo')
      end

      it 'returns an enumerator' do
        expect(subject.each).to be_a Enumerator
        expect(subject).to respond_to :first
      end
    end

    context 'when given relative: false' do
      let(:args) { { relative: false } }

      it 'returns full paths' do
        create_file_list 'foo', 'bar', 'baz'

        expect(subject).to allow_files(
          ::File.join(Dir.pwd, 'foo'), ::File.join(Dir.pwd, 'bar'), ::File.join(Dir.pwd, 'baz')
        )
      end
    end

    context 'when given shebang and include_rules' do
      let(:args) { { include_rules: ['*.rb', 'Rakefile', '#!:ruby'] } }

      it 'returns matching files' do
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
          'ignored_foo', 'bar', 'baz', 'ignored_bar/ruby.rb', 'nonexistent/file'
        )
      end
    end

    context 'when given include shebang rule scoped by a file' do
      let(:args) { { gitignore: false, include_files: 'a/.include' } }

      it 'returns matching files' do
        create_file <<~RUBY, path: 'a/foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby

          puts('no')
        RUBY

        create_file '#!:ruby', path: 'a/.include'

        expect(subject).not_to allow_files('foo')
        expect(subject).to allow_files('a/foo')
      end
    end

    context 'when given ignore shebang rule scoped by a file' do
      let(:args) { { gitignore: false, ignore_files: 'a/.ignore' } }

      it 'returns matching files' do
        create_file <<~RUBY, path: 'a/foo'
          #!/usr/bin/env ruby -w

          puts('no')
        RUBY

        create_file <<~RUBY, path: 'foo'
          #!/usr/bin/env ruby

          puts('ok')
        RUBY

        create_file '#!:ruby', '#!:bash', path: 'a/.ignore'

        expect(subject).not_to allow_files('a/foo')
        expect(subject).to allow_files('foo')
      end
    end

    context 'when given only shebang ignore rule' do
      let(:args) { { ignore_rules: ['#!:ruby'] } }

      it 'returns matching files' do
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
      let(:args) { { ignore_rules: ['#!:RUBY'] } }

      it 'returns matching files' do
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
      let(:args) { { ignore_rules: ['#!:ruby'] } }

      it 'returns matching files' do
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

    context 'when given only shebang include rule' do
      let(:args) { { include_rules: ['#!:ruby'] } }

      it 'returns matching files' do
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

    context 'when given only include_shebangs as a single value' do
      let(:args) { { include_rules: '#!:ruby' } }

      it 'returns matching files' do
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

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow_files('foo')
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb')
      end
    end

    context 'when given only include_shebangs and a root down a level' do
      let(:args) { { include_rules: '#!:ruby', root: 'sub' } }

      it 'returns matching files' do
        create_file <<~RUBY, path: 'sub/foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~RUBY, path: 'sub/ignored_foo'
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file <<~BASH, path: 'sub/bar'
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'sub/baz', 'sub/baz.rb'

        gitignore 'ignored_foo', path: 'sub/.gitignore'

        expect(subject).to allow_files('foo')
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb')
      end
    end

    context 'when given only include_shebangs and a root up a level' do
      let(:args) { { include_rules: '#!:ruby', root: '../' } }

      it 'returns matching files' do
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

        Dir.mkdir 'level'
        Dir.chdir 'level'

        expect(subject).to allow_files('foo')
        expect(subject).not_to allow_files('ignored_foo', 'bar', 'baz', 'baz.rb')
      end
    end

    context 'when given only include_shebangs as a string list' do
      let(:args) { { include_rules: "#!:ruby\n#!:bash" } }

      it 'returns matching files' do
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

    context 'when given only include_shebangs as a string list, allowed? can be shortcut with content' do
      let(:args) { { include_rules: '#!:ruby' } }

      it 'returns matching files' do
        content = <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file content, path: 'foo'

        expect(subject.allowed?('foo', content: content)).to be true
      end
    end

    context 'when given only include_shebangs as a string list, allowed? can be lied to with content' do
      let(:args) { { include_rules: '#!:bash', gitignore: false } }

      it 'returns matching files' do
        real_content = <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY
        fake_content = <<~BASH
          #!/usr/bin/env bash

          echo 'ok'
        BASH
        create_file real_content, path: 'foo'

        expect(subject.allowed?('foo', content: fake_content)).to be true
      end
    end
  end
end
