# frozen_string_literal: true

RSpec.describe FastIgnore::GlobalGitignore do
  subject { described_class.path(root: root) }

  let(:xdg_config_home) { nil }

  let(:repo_config_path_content) { nil }
  let(:global_config_path_content) { nil }
  let(:xdg_global_config_path_content) { nil }
  let(:system_config_path_content) { nil }

  let(:default_ignore_path) { "#{home}/.config/git/ignore" }

  let(:repo_config_path) { "#{root}/.git/config" }
  let(:global_config_path) { "#{home}/.gitconfig" }
  let(:xdg_global_config_path) { "#{xdg_config_home}/git/config" }
  let(:system_config_path) { '/etc/gitconfig' }
  let(:home) { ENV['HOME'] }
  let(:root) { Dir.pwd }

  let(:config_content) { "[core]\n\texcludesfile = #{excludesfile_value}\n" }
  let(:excludesfile_value) { '~/.global_gitignore' }

  around { |e| within_temp_dir { e.run } }

  before do
    allow(::ENV).to receive(:[]).at_least(:once)
      .and_call_original
    allow(::ENV).to receive(:[]).with('XDG_CONFIG_HOME').at_least(:once)
      .and_return(xdg_config_home)
    allow(::File).to receive(:readable?).at_least(:once).and_call_original
    allow(::File).to receive(:readable?).with(repo_config_path).at_least(:once)
      .and_return(!repo_config_path_content.nil?)
    allow(::File).to receive(:readable?).with(global_config_path).at_least(:once)
      .and_return(!global_config_path_content.nil?)
    allow(::File).to receive(:readable?).with(xdg_global_config_path).at_least(:once)
      .and_return(!xdg_global_config_path_content.nil?)
    allow(::File).to receive(:readable?).with(system_config_path).at_least(:once)
      .and_return(!system_config_path_content.nil?)
    allow(::File).to receive(:read).at_least(:once)
      .and_call_original
    allow(::File).to receive(:read).with(repo_config_path).at_least(:once)
      .and_return(repo_config_path_content)
    allow(::File).to receive(:read).with(global_config_path).at_least(:once)
      .and_return(global_config_path_content)
    allow(::File).to receive(:read).with(xdg_global_config_path).at_least(:once)
      .and_return(xdg_global_config_path_content)
    allow(::File).to receive(:read).with(system_config_path).at_least(:once)
      .and_return(system_config_path_content)
  end

  context 'with no excludesfile defined' do
    it 'returns the default path' do
      expect(subject).to eq default_ignore_path
    end

    context 'when XDG_CONFIG_HOME is blank' do
      let(:xdg_config_home) { '' }

      it 'returns the default path' do
        expect(subject).to eq "#{home}/.config/git/ignore"
      end
    end
  end

  context 'with excludesfile defined in a config' do
    let(:repo_config_path_content) { config_content }

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq "#{home}/.global_gitignore"
    end

    context 'when excludesfile value is quoted' do
      let(:excludesfile_value) { '"~/.global_gitignore_in_quotes"' }

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/.global_gitignore_in_quotes"
      end
    end

    context 'when excludesfile value is invalid' do
      let(:excludesfile_value) { '"~/.global_gitignore_in_quotes' } # no closing quote

      it 'raises' do
        expect { subject }.to raise_error FastIgnore::GitconfigParseError
      end

      context 'when there is a global config file defined' do
        let(:global_config_path_content) { "[core]\n\texcludesfile = ~/.global_gitignore" }

        it 'still raises' do
          expect { subject }.to raise_error FastIgnore::GitconfigParseError
        end
      end
    end

    context 'when excludesfile value is missing from that file' do
      context 'when there is a global config file defined' do
        let(:repo_config_path_content) { "[core]\n\tattributesfile = ~/.global_gitattributes" }
        let(:global_config_path_content) { config_content }

        it 'returns a literal unquoted value for the path' do
          expect(subject).to eq "#{home}/.global_gitignore"
        end
      end
    end

    context 'when excludesfile value includes # character in the name in quotes' do
      let(:excludesfile_value) { '"~/.global_gitignore_with_#_in_quotes"' }

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/.global_gitignore_with_#_in_quotes"
      end
    end
  end

  context 'with excludesfile defined in a system config' do
    let(:excludesfile_value) { '"/.system_git_ignore"' }
    let(:system_config_path_content) { config_content }

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq '/.system_git_ignore'
    end
  end

  context 'when the global gitconfig sets the excludesfile to blank' do
    context 'when the excludesfile value is blank' do
      let(:global_config_path_content) { config_content }
      let(:excludesfile_value) { '' }

      it "doesn't fall back" do
        expect(subject).to eq ''
      end
    end
  end

  context 'when XDG_CONFIG_HOME points to a different dir' do
    let(:xdg_config_home) { "#{home}/.xconfig" }

    it 'returns a default value within xdg dir for the path' do
      expect(subject).to eq "#{home}/.xconfig/git/ignore"
    end

    context 'when the xdg config sets an ignore path' do
      let(:xdg_global_config_path_content) { "[core]\n\texcludesfile = ~/.x_global_gitignore" }

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/.x_global_gitignore"
      end

      context 'with .gitconfig file also' do
        let(:global_config_path_content) { config_content }

        it 'returns a literal unquoted value from .gitconfig for the path' do
          expect(subject).to eq "#{home}/.global_gitignore"
        end
      end
    end
  end
end
