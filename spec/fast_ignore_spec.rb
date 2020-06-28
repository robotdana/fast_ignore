# frozen_string_literal: true

# raise warnings
module Warning # leftovers:allow
  def warn(msg) # leftovers:allow
    raise msg
  end
end

require 'pathname'

RSpec.describe FastIgnore do
  it 'has a version number' do
    expect(FastIgnore::VERSION).not_to be nil
  end

  describe 'FastIgnore' do
    subject { described_class.new(relative: true, **args) }

    let(:args) { {} }

    around { |e| within_temp_dir { e.run } }

    it 'returns all files when there is no gitignore' do
      create_file_list 'foo', 'bar'
      expect(subject).to allow_exactly('foo', 'bar')
    end

    context 'when gitignore: false' do
      let(:args) { { gitignore: false } }

      it 'returns all files when there is no gitignore' do
        create_file_list 'foo', 'bar'
        expect(subject).to allow_exactly('foo', 'bar')
      end

      it 'ignores the given gitignore file and returns all files anyway' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo', 'bar'

        gitignore <<~GITIGNORE
          foo
          bar
        GITIGNORE

        expect(subject).to allow_files('foo', 'bar')
      end
    end

    it 'matches uppercase paths to lowercase patterns' do
      create_file_list 'FOO'
      gitignore <<~GITIGNORE
        foo
      GITIGNORE

      expect(subject).to disallow('FOO')
    end

    it 'matches lowercase paths to uppercase patterns' do
      create_file_list 'foo'
      gitignore <<~GITIGNORE
        FOO
      GITIGNORE

      expect(subject).to disallow('foo')
    end

    describe 'Patterns read from gitignore referred by gitconfig' do
      before do
        create_file_list 'a/b/c', 'a/b/d', 'b/c', 'b/d'

        gitignore <<~GITIGNORE
          b/d
        GITIGNORE

        allow(File).to receive(:exist?).at_least(:once).and_call_original
        allow(File).to receive(:readlines).at_least(:once).and_call_original
        allow(ENV).to receive(:[]).at_least(:once).and_call_original
      end

      it 'recognises ~/.gitconfig gitignore files' do # rubocop:disable RSpec/ExampleLength
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return(nil)
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return([
          "[core]\n".dup,
          "\texcludesfile = ~/.global_gitignore\n".dup
        ])

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.global_gitignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.global_gitignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'recognises XDG_CONFIG_HOME gitconfig gitignore files' do # rubocop:disable RSpec/ExampleLength
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return("#{ENV['HOME']}/.xconfig")
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.xconfig/git/config").at_least(:once).and_return(true)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.xconfig/git/config").at_least(:once).and_return([
          "[core]\n".dup,
          "\texcludesfile = ~/.global_gitignore\n".dup
        ])

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.global_gitignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.global_gitignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'recognises XDG_CONFIG_HOME gitconfig gitignore files but home .gitconfig overrides' do # rubocop:disable RSpec/ExampleLength
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return("#{ENV['HOME']}/.xconfig")
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.xconfig/git/config").at_least(:once).and_return(true)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.xconfig/git/config").at_least(:once).and_return([
          "[core]\n".dup,
          "\texcludesfile = ~/.x_global_gitignore\n".dup
        ])

        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return([
          "[core]\n".dup,
          "\texcludesfile = ~/.global_gitignore\n".dup
        ])

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.global_gitignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.global_gitignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.x_global_gitignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.x_global_gitignore")
          .at_least(:once).and_return(["a/b/d\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'recognises default global gitignore file when XDG_CONFIG_HOME is blank' do # rubocop:disable RSpec/ExampleLength
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(false)
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return('')
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.config/git/ignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.config/git/ignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'recognises default global gitignore file when XDG_CONFIG_HOME is nil' do # rubocop:disable RSpec/ExampleLength
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return(nil)

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.config/git/ignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.config/git/ignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'recognises default global gitignore file when gitconfig has no excludesfile and XDG_CONFIG_HOME is nil' do # rubocop:disable RSpec/ExampleLength
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return([
          "[user]\n".dup,
          "\tname = Dana \n".dup
        ])
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return(nil)

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.config/git/ignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.config/git/ignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'ignores default global gitignore file when gitconfig has blank excludes file' do # rubocop:disable RSpec/ExampleLength
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return([
          "[core]\n".dup,
          "\texcludesfile =\n".dup
        ])
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return(nil)

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.config/git/ignore")
          .and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.config/git/ignore")
          .and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c', 'a/b/c').and(disallow('b/d'))
      end

      it 'recognises default global gitignore file when XDG_CONFIG_HOME is set' do # rubocop:disable RSpec/ExampleLength
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return('~/.xconfig')
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)

        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.xconfig/git/ignore")
          .at_least(:once).and_return(true)
        allow(File).to receive(:readlines).with("#{ENV['HOME']}/.xconfig/git/ignore")
          .at_least(:once).and_return(["a/b/c\n".dup])

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      it 'recognises project .gitignore file when no global gitignore' do # rubocop:disable RSpec/ExampleLength
        allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(false)
        allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return(nil)
        allow(File).to receive(:exist?).with("#{ENV['HOME']}/.config/git/ignore").at_least(:once).and_return(false)

        create_file 'a/.gitignore', <<~GITIGNORE
          b/c
        GITIGNORE

        expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
      end

      context 'when no global gitignore' do
        before do
          allow(File).to receive(:exist?).with('/etc/gitconfig').at_least(:once).and_return(false)
          allow(File).to receive(:exist?).with("#{Dir.pwd}/.git/gitconfig").at_least(:once).and_return(false)

          allow(File).to receive(:exist?).with("#{ENV['HOME']}/.gitconfig").at_least(:once).and_return(false)
          allow(ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once).and_return(nil)
          allow(File).to receive(:exist?).with("#{ENV['HOME']}/.config/git/ignore").at_least(:once).and_return(false)
        end

        it 'recognises project subdir .gitignore file and no project dir gitignore' do # rubocop:disable RSpec/ExampleLength
          gitignore ''

          create_file 'a/.gitignore', <<~GITIGNORE
            /b/c
          GITIGNORE

          create_file 'b/.gitignore', <<~GITIGNORE
            d
          GITIGNORE

          expect(subject).to allow_files('a/b/d', 'b/c').and(disallow('a/b/c', 'b/d'))
        end

        it 'recognises project subdir .gitignore file when one is empty when no project dir gitignore' do # rubocop:disable RSpec/ExampleLength
          gitignore ''

          create_file 'a/.gitignore', <<~GITIGNORE
            # this is just a comment
          GITIGNORE

          create_file 'a/b/.gitignore', <<~GITIGNORE
            /d
          GITIGNORE

          expect(subject).to allow_files('b/c', 'a/b/c', 'b/d', 'b/d').and(disallow('a/b/d'))
        end
      end
    end

    context 'with subdir includes file' do
      before { create_file_list 'a/b/c', 'a/b/d', 'a/b/e', 'b/c', 'b/d', 'a/c' }

      let(:args) { { gitignore: false, include_files: ['a/.includes_file'] } }

      it 'recognises subdir includes file' do
        create_file 'a/.includes_file', <<~INCLUDEFILE
          /b/d
          c
        INCLUDEFILE

        expect(subject).to allow_files('a/c', 'a/b/d', 'a/b/c').and(disallow('b/c', 'b/d', 'a/b/e'))
      end
    end

    context 'when ignore_files is outside root' do
      let(:args) { { ignore_files: '~/.gitignore' } }

      it 'raises an error' do
        expect { subject.to_a }.to raise_error(FastIgnore::Error)
      end
    end

    it 'returns hidden files' do
      create_file_list '.gitignore', '.a', '.b/.c'

      expect(subject).to allow_exactly('.gitignore', '.a', '.b/.c')
    end

    it 'allowed? returns false nonexistent files' do
      expect(subject.allowed?('utter/nonsense')).to be false
    end

    it 'allowed? can be shortcut with directory:' do
      create_file_list 'a'
      expect(subject.allowed?('a', directory: false)).to be true
    end

    it 'allowed? can be lied to with directory:' do
      create_file_list 'a/b'
      expect(subject.allowed?('a', directory: false)).to be true
    end

    it 'rescues soft links to nowhere' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')
      FileUtils.rm('foo_target')

      expect(subject).to allow_files('foo')
      expect(subject.select { |x| File.read(x) }.to_a).to contain_exactly('.gitignore')
    end

    it 'allows soft links to directories' do # rubocop:disable RSpec/ExampleLength
      create_file_list 'foo_target/foo_child', '.gitignore'
      gitignore <<~GITIGNORE
        foo_target
      GITIGNORE

      create_symlink('foo' => 'foo_target')
      expect(subject).to allow_exactly('foo', '.gitignore')
    end

    it 'allows soft links' do
      create_file_list 'foo_target', '.gitignore'
      create_symlink('foo' => 'foo_target')

      expect(subject).to allow_exactly('foo', 'foo_target', '.gitignore')
    end

    context 'with follow_symlinks: true' do
      let(:args) { { follow_symlinks: true } }

      it 'ignores soft links to nowhere' do
        create_file_list 'foo_target', '.gitignore'
        create_symlink('foo' => 'foo_target')
        FileUtils.rm('foo_target')

        expect(subject).to disallow('foo', 'foo_target').and(allow_files('.gitignore'))
      end

      it 'allows soft links to directories' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo_target/foo_child', '.gitignore'
        gitignore <<~GITIGNORE
          foo_target
        GITIGNORE

        create_symlink('foo' => 'foo_target')
        expect(subject).to allow_exactly('foo/foo_child', '.gitignore')
      end

      it 'allows soft links' do
        create_file_list 'foo_target', '.gitignore'
        create_symlink('foo' => 'foo_target')

        expect(subject).to allow_exactly('foo', 'foo_target', '.gitignore')
      end
    end

    context 'when given a file other than gitignore' do
      let(:args) { { gitignore: false, ignore_files: File.join(Dir.pwd, 'fancyignore') } }

      it 'reads the non-gitignore file' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        create_file 'fancyignore', <<~FANCYIGNORE
          foo
        FANCYIGNORE

        expect(subject).to disallow('foo').and(allow_files('bar', 'baz'))
      end
    end

    context 'when given a file including gitignore' do
      let(:args) { { ignore_files: File.join(Dir.pwd, 'fancyignore') } }

      it 'reads the non-gitignore file and the gitignore file' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        create_file 'fancyignore', <<~FANCYIGNORE
          foo
        FANCYIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow_files('baz'))
      end
    end

    context 'when given an array of ignore_rules' do
      let(:args) { { gitignore: false, ignore_rules: 'foo' } }

      it 'reads the list of rules' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo').and(allow_files('bar', 'baz'))
      end
    end

    context 'when given an array of ignore_rules and gitignore' do
      let(:args) { { ignore_rules: 'foo' } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow_files('baz'))
      end
    end

    context 'when given an array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar', 'baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow_files('baz'))
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

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow_files('baz'))
      end
    end

    context 'when given a small array of include_rules and gitignore' do
      let(:args) { { include_rules: ['bar'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar', 'baz/bar'

        gitignore <<~GITIGNORE
          foo
        GITIGNORE

        expect(subject).to disallow('foo/bar').and(allow_files('baz/bar'))
      end
    end

    context 'when given an array of include_rules beginning with `/` and gitignore' do
      let(:args) { { include_rules: ['/bar', '/baz'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/bar/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo/bar/foo', 'foo/bar/baz', 'bar/foo').and(allow_files('baz'))
      end
    end

    context 'when given an array of include_rules ending with `/` and gitignore' do
      let(:args) { { include_rules: ['bar/', 'baz/'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo/baz/foo', 'foo/bar/baz', 'bar/foo', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('baz', 'foo/bar/baz', 'bar/foo').and(allow_files('foo/baz/foo'))
      end
    end

    context 'when given an array of include_rules with `!` and gitignore' do
      let(:args) { { include_rules: ['fo*', '!foo', 'food'] } }

      it 'reads the list of rules and gitignore' do
        create_file_list 'foo', 'food', 'foe', 'for'

        gitignore <<~GITIGNORE
          for
        GITIGNORE

        expect(subject).to disallow('foo', 'for').and(allow_files('foe', 'food'))
      end
    end

    context 'when given an array of argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['./bar', "#{Dir.pwd}/baz"] } }

      it 'resolves the paths to the current directory' do
        create_file_list 'foo', 'bar', 'baz'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'bar').and(allow_files('baz'))
      end
    end

    context 'when given an array of negated argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['*', '!./foo', "!#{Dir.pwd}/baz"] } }

      it 'resolves the paths even when negated' do
        create_file_list 'foo', 'bar', 'baz', 'boo'

        gitignore <<~GITIGNORE
          bar
        GITIGNORE

        expect(subject).to disallow('foo', 'baz', 'bar').and(allow_files('boo'))
      end
    end

    context 'when given an array of unanchored argv_rules' do
      let(:args) { { argv_rules: ['**/foo', '*baz'] } }

      it 'treats the rules as unanchored' do
        create_file_list 'bar/foo', 'bar/baz', 'bar/bar', 'foo', 'baz/foo', 'baz/baz'

        expect(subject).to disallow('bar/bar', 'baz', 'bar')
          .and(allow_files('bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz'))
      end
    end

    context 'when given an array of anchored argv_rules with absolute paths and gitignore' do
      let(:args) { { argv_rules: ['foo', 'baz'] } }

      it 'anchors the rules to the given dir, for performance reasons' do
        create_file_list 'bar/foo', 'bar/baz', 'foo', 'baz/foo', 'baz/baz'

        expect(subject).to disallow('bar/foo', 'bar/baz').and(allow_files('foo', 'baz/foo', 'baz/baz'))
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

      it 'returns relative to the root' do # rubocop:disable RSpec/ExampleLength
        create_file_list 'bar/foo', 'bar/baz', 'fez', 'baz/foo', 'baz/baz'
        gitignore <<~GITIGNORE
          baz
        GITIGNORE

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
          .and(disallow(Dir.pwd + '/bar', Dir.pwd + '/fez'))
      end
    end

    context 'when given an array of argv_rules and include_rules' do
      let(:args) { { argv_rules: ['foo', 'baz'], include_rules: ['foo', 'bar'] } }

      it 'adds the rulesets, they must pass both lists' do
        create_file_list 'foo', 'bar', 'baz'

        expect(subject).to disallow('baz', 'bar').and(allow_files('foo'))
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

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'sub/foo', <<~RUBY
          #!/usr/bin/env ruby -w --disable-gems --verbose --enable-frozen-string-literal

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_bar/ruby.rb', <<~RUBY
          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file 'Rakefile', <<~RUBY
          puts "ok"
        RUBY

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
          ignored_bar
        GITIGNORE

        expect(subject).to allow_files('sub/foo', 'foo', 'baz.rb', 'Rakefile')
          .and(disallow('ignored_foo', 'bar', 'baz', 'ignored_bar/ruby.rb', 'nonexistent/file'))
      end
    end

    context 'when given only shebang ignore rule' do
      let(:args) { { ignore_rules: ['#!:ruby'] } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('no')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo ok
        BASH

        expect(subject).to disallow('foo').and(allow_files('bar'))
      end
    end

    context 'when given UPPERCASE shebang ignore rule' do
      let(:args) { { ignore_rules: ['#!:RUBY'] } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('no')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo ok
        BASH

        expect(subject).to disallow('foo').and(allow_files('bar'))
      end
    end

    context "when given lowercase shebang ignore rule with uppercase shebang (I don't know your life)" do
      let(:args) { { ignore_rules: ['#!:ruby'] } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/USR/BIN/ENV RUBY

          puts('no')
        RUBY

        create_file 'bar', <<~BASH
          #!/USR/BIN/ENV BASH

          echo ok
        BASH

        expect(subject).to disallow('foo').and(allow_files('bar'))
      end
    end

    context 'when given only shebang include rule' do
      let(:args) { { include_rules: ['#!:ruby'] } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'sub/foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_bar/ruby', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_bar
          ignored_foo
        GITIGNORE

        expect(subject).to allow_files('sub/foo', 'foo')
          .and(disallow('ignored_foo', 'bar', 'baz', 'baz.rb', 'ignored_bar/ruby'))
      end
    end

    context 'when given only include_shebangs as a single value' do
      let(:args) { { include_rules: '#!:ruby' } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow_files('foo').and(disallow('ignored_foo', 'bar', 'baz', 'baz.rb'))
      end
    end

    context 'when given only include_shebangs and a root down a level' do
      let(:args) { { include_rules: '#!:ruby', root: 'sub' } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'sub/foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'sub/ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'sub/bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'sub/baz', 'sub/baz.rb'

        create_file 'sub/.gitignore', <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow_files('foo').and(disallow('ignored_foo', 'bar', 'baz', 'baz.rb'))
      end
    end

    context 'when given only include_shebangs and a root up a level' do
      let(:args) { { include_rules: '#!:ruby', root: '../' } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        create_file '.gitignore', <<~GITIGNORE
          ignored_foo
        GITIGNORE

        Dir.mkdir 'level'
        Dir.chdir 'level'

        expect(subject).to allow_files('foo').and(disallow('ignored_foo', 'bar', 'baz', 'baz.rb'))
      end
    end

    context 'when given only include_shebangs as a string list' do
      let(:args) { { include_rules: "#!:ruby\n#!:bash" } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        create_file 'foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'ignored_foo', <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY

        create_file 'bar', <<~BASH
          #!/usr/bin/env bash

          echo -e "no"
        BASH

        create_file_list 'baz', 'baz.rb'

        gitignore <<~GITIGNORE
          ignored_foo
        GITIGNORE

        expect(subject).to allow_files('foo', 'bar').and(disallow('ignored_foo', 'baz', 'baz.rb'))
      end
    end

    context 'when given only include_shebangs as a string list, allowed? can be shortcut with content' do
      let(:args) { { include_rules: '#!:ruby' } }

      it 'returns matching files' do
        content = <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY
        create_file 'foo', content

        expect(subject.allowed?('foo', content: content)).to be true
      end
    end

    context 'when given only include_shebangs as a string list, allowed? can be lied to with content' do
      let(:args) { { include_rules: '#!:bash' } }

      it 'returns matching files' do # rubocop:disable RSpec/ExampleLength
        real_content = <<~RUBY
          #!/usr/bin/env ruby -w

          puts('ok')
        RUBY
        fake_content = <<~BASH
          #!/usr/bin/env bash

          echo 'ok'
        BASH
        create_file 'foo', real_content

        expect(subject.allowed?('foo', content: fake_content)).to be true
      end
    end
  end
end
