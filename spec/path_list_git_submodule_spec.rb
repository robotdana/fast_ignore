# frozen_string_literal: true

RSpec.describe PathList do
  within_temp_dir

  let(:root) { Dir.pwd }

  shared_examples 'gitignore' do
    let(:parent_repo) { real_git('./parent_repo') }
    let(:submodule_foo) { real_git('./submodule_foo') }
    let(:submodule_bar) { real_git('./submodule_bar') }

    before do
      submodule_bar.commit('--allow-empty')
      submodule_foo.add_submodule(submodule_bar.path)
      submodule_foo.commit
      parent_repo.add_submodule(submodule_foo.path)
    end

    it 'considers patterns in the global config is relative to submodule root' do
      gitignore '/a', path: '.global_gitignore'

      parent_repo.configure_excludesfile("#{Dir.pwd}/.global_gitignore")
      parent_repo.configure_excludesfile("#{Dir.pwd}/.global_gitignore", chdir: "#{Dir.pwd}/parent_repo/submodule_foo")
      parent_repo.configure_excludesfile("#{Dir.pwd}/.global_gitignore",
                                         chdir: "#{Dir.pwd}/parent_repo/submodule_foo/submodule_bar")

      create_file_list(
        'parent_repo/a',
        'parent_repo/b/a',
        'parent_repo/submodule_foo/a',
        'parent_repo/submodule_foo/b/a',
        'parent_repo/submodule_foo/submodule_bar/a',
        'parent_repo/submodule_foo/submodule_bar/b/a'
      )

      Dir.chdir(parent_repo.path) do
        require 'pry'
        binding.pry

        expect(subject).to match_files(
          'a',
          'submodule_foo/a',
          'submodule_foo/submodule_bar/a'
        )

        expect(subject).not_to match_files(
          'parent_repo/b/a',
          'parent_repo/submodule_foo/b/a',
          'parent_repo/submodule_foo/submodule_bar/b/a'
        )
      end
    end

    it 'config relative to submodule' do
      Dir.chdir(parent_repo.path) do
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
    subject { described_class.gitignore(root: parent_repo.path) }

    it_behaves_like 'gitignore'
  end

  describe 'git ls-files', :real_git do
    subject { parent_repo }

    it_behaves_like 'gitignore'
  end
end
