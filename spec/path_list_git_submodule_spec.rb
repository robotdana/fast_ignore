# frozen_string_literal: true

RSpec.describe PathList do
  within_temp_dir

  let(:root) { Dir.pwd }

  shared_examples 'gitignore' do
    let(:parent_repo) { RealGit.new('./parent_repo') }
    let(:submodule_foo) { RealGit.new('./submodule_foo') }
    let(:submodule_bar) { RealGit.new('./submodule_bar') }

    before do
      submodule_bar.commit('--allow-empty')
      submodule_foo.add_submodule(submodule_bar.path)
      submodule_foo.commit
      parent_repo.add_submodule(submodule_foo.path)
    end

    # NOTE: .git is a file when a submodule
    it 'ignore .git in submodule' do
      subject

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
    subject { described_class.gitignore(root: './parent') }

    it_behaves_like 'gitignore'
  end

  describe 'git ls-files', :real_git do
    subject { parent_repo }

    it_behaves_like 'gitignore'
  end
end
