# frozen_string_literal: true

RSpec.describe PathList do
  within_temp_dir

  let(:root) { Dir.pwd }
  let(:repo_path) { File.join(root, 'repo') }

  shared_examples 'gitignore' do
    it 'considers patterns in the global config relative to submodule root' do
      gitignore '/a'

      global_config_path = "#{root}/config"
      create_file(<<~GIT_CONFIG, path: global_config_path)
        [core]
          excludesfile = "#{root}/.gitignore"
      GIT_CONFIG
      stub_env(GIT_CONFIG_GLOBAL: global_config_path)

      setup_gitmodules

      Dir.chdir(repo_path) do
        expect(subject).to match_files(
          'a',
          'submodule_foo/a',
          'submodule_foo/submodule_bar/a'
        )

        expect(subject).not_to match_files(
          'b/a',
          'submodule_foo/b/a',
          'submodule_foo/submodule_bar/b/a'
        )
      end
    end

    it 'skips rules for earlier repos' do
      setup_gitmodules

      Dir.chdir(repo_path) do
        gitignore 'a'
        expect(subject).to match_files(
          'a',
          'b/a'
        )

        expect(subject).not_to match_files(
          'submodule_foo/a',
          'submodule_foo/b/a',
          'submodule_foo/submodule_bar/a',
          'submodule_foo/submodule_bar/b/a'
        )
      end
    end

    it 'reads the local git config for the submodule' do
      setup_submodule_config_exclude
      gitignore '/a', 'c'

      Dir.chdir(repo_path) do
        expect(subject).to match_files(
          'submodule_foo/a',
          'submodule_foo/c',
          'submodule_foo/b/c'
        )

        expect(subject).not_to match_files(
          'a',
          'b/a',
          'c',
          'b/c',
          'submodule_foo/b/a',
          'submodule_foo/submodule_bar/a',
          'submodule_foo/submodule_bar/c',
          'submodule_foo/submodule_bar/b/a',
          'submodule_foo/submodule_bar/b/c'
        )
      end
    end

    it 'reads the info/exclude for the submodule' do
      setup_submodule_git_dir
      create_file '/a', 'c', path: 'repo/.git/modules/submodule_foo/info/exclude', force: true

      Dir.chdir(repo_path) do
        expect(subject).to match_files(
          'submodule_foo/a',
          'submodule_foo/c',
          'submodule_foo/b/c'
        )

        expect(subject).not_to match_files(
          'a',
          'b/a',
          'c',
          'b/c',
          'submodule_foo/b/a',
          'submodule_foo/submodule_bar/a',
          'submodule_foo/submodule_bar/c',
          'submodule_foo/submodule_bar/b/a',
          'submodule_foo/submodule_bar/b/c'
        )
      end
    end

    it 'collects its own gitignore for the submodule' do
      setup_submodule_git_dir
      create_file '/a', path: 'repo/submodule_foo/b/.gitignore'

      Dir.chdir(repo_path) do
        expect(subject).to match_files(
          'submodule_foo/b/a'
        )

        expect(subject).not_to match_files(
          'a',
          'b/a',
          'submodule_foo/a',
          'submodule_foo/submodule_bar/a',
          'submodule_foo/submodule_bar/b/a'
        )
      end
    end

    it 'always allows the submodule' do
      setup_submodule_git_dir
      create_file '/sub*', path: 'repo/submodule_foo/.gitignore'

      Dir.chdir(repo_path) do
        expect(subject).to match_files(
          'submodule_foo/submarine'
        )

        expect(subject).not_to match_files(
          'boat',
          'submarine',
          'submodule_foo/boat',
          'submodule_foo/submodule_bar/boat',
          'submodule_foo/submodule_bar/submarine'
        )
      end
    end

    it 'reads config relative to submodule' do
      setup_gitmodules

      Dir.chdir(repo_path) do
        expect(subject).to match_files(
          '.git/WHATEVER',
          'submodule_foo/.git',
          'submodule_foo/submodule_bar/.git',
          'fake_submodule/.git',
          'fake_other_repo/.git/WHATEVER'
        )

        expect(subject).not_to match_files(
          '.gitmodules', 'submodule_foo/.gitmodules', 'WHATEVER'
        )
      end
    end
  end

  describe '.gitignore' do
    subject { described_class.gitignore }

    let(:setup_gitmodules) do
      # the correctness of this setup is checked in the next describe
      create_file <<~GIT_CONFIG, path: "#{repo_path}/.gitmodules"
        [submodule "submodule_foo"]
        \tpath = submodule_foo
        \turl = #{root}/submodule_foo
      GIT_CONFIG
      create_file <<~GIT_CONFIG, path: "#{repo_path}/submodule_foo/.gitmodules"
        [submodule "submodule_bar"]
        \tpath = submodule_bar
        \turl = #{root}/submodule_bar
      GIT_CONFIG
    end

    let(:setup_submodule_config_exclude) do
      setup_submodule_git_dir

      create_file(<<~GIT_CONFIG, path: "#{repo_path}/.git/modules/submodule_foo/config")
        [core]
        \texcludesfile = #{root}/.gitignore
      GIT_CONFIG
    end

    let(:setup_submodule_git_dir) do
      setup_gitmodules

      create_file(<<~GIT, path: "#{repo_path}/submodule_foo/.git")
        gitdir: ../.git/modules/submodule_foo
      GIT

      create_file(<<~GIT, path: "#{repo_path}/submodule_foo/submodule_bar/.git")
        gitdir: ../../.git/modules/submodule_foo/modules/submodule_bar
      GIT
    end

    it_behaves_like 'gitignore'
  end

  describe 'git ls-files', :real_git do
    subject { real_git_repo }

    let(:real_git_repo) { real_git(repo_path) }
    let(:real_git_submodule_foo) { real_git('submodule_foo') }
    let(:real_git_submodule_bar) { real_git('submodule_bar') }
    let(:setup_submodule_git_dir) { setup_gitmodules }

    let(:setup_gitmodules) do
      real_git_submodule_bar.commit('--allow-empty')
      real_git_submodule_foo.add_submodule(real_git_submodule_bar.path)
      real_git_submodule_foo.commit
      real_git_repo.add_submodule(real_git_submodule_foo.path)
    end

    let(:setup_submodule_config_exclude) do
      setup_gitmodules

      real_git_repo.submodule(
        'foreach',
        Shellwords.join(
          ['git', 'config', 'set', '--local', 'core.excludesfile', "#{root}/.gitignore"]
        )
      )
    end

    it 'has correct setup in the other branch' do
      setup_gitmodules

      expect(File.read("#{repo_path}/.gitmodules")).to eq <<~GIT_CONFIG
        [submodule "submodule_foo"]
        \tpath = submodule_foo
        \turl = #{root}/submodule_foo
      GIT_CONFIG

      expect(File.read("#{repo_path}/submodule_foo/.gitmodules")).to eq <<~GIT_CONFIG
        [submodule "submodule_bar"]
        \tpath = submodule_bar
        \turl = #{root}/submodule_bar
      GIT_CONFIG

      expect(File.read("#{repo_path}/submodule_foo/.git")).to eq <<~GIT
        gitdir: ../.git/modules/submodule_foo
      GIT

      expect(File.read("#{repo_path}/submodule_foo/submodule_bar/.git")).to eq <<~GIT
        gitdir: ../../.git/modules/submodule_foo/modules/submodule_bar
      GIT

      setup_submodule_config_exclude

      expect(File.read("#{repo_path}/.git/modules/submodule_foo/config")).to match %r{
        \[core\]\n
        (?:\t.*$\n)*
        \texcludesfile\s=\s#{root}/.gitignore\n
        \[
      }x
    end

    it_behaves_like 'gitignore'
  end
end
