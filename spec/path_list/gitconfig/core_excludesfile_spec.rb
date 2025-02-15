# frozen_string_literal: true

RSpec.describe(PathList::Gitconfig::CoreExcludesfile) do
  subject { described_class.path(git_dir: git_dir) }

  let(:default_ignore_path) { "#{home}/.config/git/ignore" }

  let(:home) { File.expand_path(Dir.home) }
  let(:git_dir) { Dir.pwd + '/.git' }

  let(:config_content) { "[core]\n\texcludesfile = #{excludesfile_value}\n" }
  let(:excludesfile_value) { '~/.global_gitignore' }

  before do
    stub_blank_global_config
  end

  context 'with no core.excludesfile defined' do
    it 'returns the default path' do
      expect(subject).to eq default_ignore_path
    end

    context 'when XDG_CONFIG_HOME is blank' do
      before do
        stub_env(XDG_CONFIG_HOME: '')
      end

      it 'returns the default path' do
        expect(subject).to eq default_ignore_path
      end
    end

    context 'when XDG_CONFIG_HOME is set' do
      before do
        stub_env(XDG_CONFIG_HOME: "#{home}/.xconfig")
      end

      it 'returns the default path' do
        expect(subject).to eq "#{home}/.xconfig/git/ignore"
      end
    end
  end

  context 'with excludesfile defined in repo config' do
    before do
      stub_file(config_content, path: "#{git_dir}/config")
    end

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq "#{home}/.global_gitignore"
    end

    context 'when excludesfile value is quoted' do
      let(:excludesfile_value) { '"~/.global_gitignore_in_quotes"' }

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/.global_gitignore_in_quotes"
      end
    end

    context 'when excludesfile value includes # character in the name in quotes' do
      let(:excludesfile_value) { '"~/.global_gitignore_with_#_in_quotes"' }

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/.global_gitignore_with_#_in_quotes"
      end
    end

    context 'when excludesfile value is invalid' do
      let(:excludesfile_value) { '"~/.global_gitignore_in_quotes' } # no closing quote

      it 'returns nil instead of default' do
        allow(Warning).to receive(:warn)
        expect(subject).to be_nil
        expect(Warning).to have_received(:warn).with(<<~MESSAGE)
          PathList gitconfig parser failed
          Unexpected character in quoted value
          #{Dir.pwd}/.git/config:2:46
          \texcludesfile = "~/.global_gitignore_in_quotes
                                                        ^
        MESSAGE
      end

      context 'when there is a valid global config file defined' do
        before do
          stub_file(<<~GITCONFIG, path: "#{home}/.gitconfig")
            [core]
              excludesfile = ~/.global_gitignore
          GITCONFIG
        end

        it 'still returns nil because any config is invalid' do
          allow(Warning).to receive(:warn)
          expect(subject).to be_nil
          expect(Warning).to have_received(:warn).with(<<~MESSAGE)
            PathList gitconfig parser failed
            Unexpected character in quoted value
            #{Dir.pwd}/.git/config:2:46
            \texcludesfile = "~/.global_gitignore_in_quotes
                                                          ^
          MESSAGE
        end
      end
    end
  end

  context "when repo config exists but doesn't set excludesfile, and global config file does" do
    before do
      stub_file(<<~GITCONFIG, path: "#{git_dir}/config")
        [core]
          attributesfile = ~/.global_gitattributes
      GITCONFIG
      stub_file(config_content, path: "#{home}/.gitconfig")
    end

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq "#{home}/.global_gitignore"
    end
  end

  context 'with excludesfile defined in a system config' do
    before do
      stub_file(config_content, path: '/usr/local/etc/gitconfig')
    end

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq "#{home}/.global_gitignore"
    end

    context 'with GIT_CONFIG_SYSTEM set' do
      before do
        stub_env(GIT_CONFIG_SYSTEM: '/usr/local/etc/other_gitconfig')
        stub_file(<<~GITCONFIG, path: '/usr/local/etc/other_gitconfig')
          [core]
            excludesfile = /system/gitignore
        GITCONFIG
      end

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{FSROOT}system/gitignore"
      end

      context 'with GIT_CONFIG_NOSYSTEM set' do
        before do
          stub_env(GIT_CONFIG_NOSYSTEM: 'true')
        end

        it 'returns the default value, ignoring system' do
          expect(subject).to eq default_ignore_path
        end
      end

      context 'with GIT_CONFIG_SYSTEM set to /dev/null' do
        before do
          stub_env(GIT_CONFIG_SYSTEM: '/dev/null')
        end

        it 'returns the default value, ignoring system' do
          expect(subject).to eq default_ignore_path
        end
      end
    end

    context 'with GIT_CONFIG_NOSYSTEM set' do
      before do
        stub_env(GIT_CONFIG_NOSYSTEM: 'true')
      end

      it 'returns the default value, ignoring system' do
        expect(subject).to eq default_ignore_path
      end
    end

    context 'with GIT_CONFIG_NOSYSTEM set to false' do
      before do
        stub_env(GIT_CONFIG_NOSYSTEM: 'false')
      end

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/.global_gitignore"
      end
    end

    context 'with GIT_CONFIG_NOSYSTEM set to a non-boolean value' do
      before do
        stub_env(GIT_CONFIG_NOSYSTEM: 'nonsense')
      end

      it 'returns nil, because git considers that a fatal error' do
        allow(Warning).to receive(:warn)
        expect(subject).to be_nil
        expect(Warning).to have_received(:warn).with(<<~MESSAGE.chomp)
          PathList gitconfig parser failed
          Bad boolean environment value "nonsense" for $GIT_CONFIG_NOSYSTEM
        MESSAGE
      end
    end
  end

  context 'when the global gitconfig is defined' do
    before do
      stub_file(config_content, path: "#{home}/.gitconfig")
    end

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq "#{home}/.global_gitignore"
    end

    context 'when the excludesfile value is blank' do
      let(:excludesfile_value) { '' }

      it 'returns nil instead of default' do
        expect(subject).to be_nil
      end
    end

    context 'with GIT_CONFIG_GLOBAL set' do
      before do
        stub_env(GIT_CONFIG_GLOBAL: "#{home}/other_gitconfig")
        stub_file(<<~GITCONFIG, path: "#{home}/other_gitconfig")
          [core]
            excludesfile = ~/other_gitignore
        GITCONFIG
      end

      it 'returns a literal unquoted value for the path' do
        expect(subject).to eq "#{home}/other_gitignore"
      end
    end

    context 'with GIT_CONFIG_GLOBAL set without excludesfile' do
      before do
        stub_env(GIT_CONFIG_GLOBAL: "#{home}/other_gitconfig")
        stub_file(<<~GITCONFIG, path: "#{home}/other_gitconfig")
          [core]
            attributesfile = ~/gitattributes
        GITCONFIG
      end

      it 'returns the default value, skipping global config files' do
        expect(subject).to eq default_ignore_path
      end
    end
  end

  context 'when XDG_CONFIG_HOME is set and sets an excludesfile' do
    before do
      stub_env(XDG_CONFIG_HOME: "#{home}/.xconfig")
      stub_file(<<~GITCONFIG, path: "#{home}/.xconfig/git/config")
        [core]
          excludesfile = ~/.x_global_gitignore
      GITCONFIG
    end

    it 'returns a literal unquoted value for the path' do
      expect(subject).to eq "#{home}/.x_global_gitignore"
    end

    context 'with GIT_CONFIG_GLOBAL set to /dev/null' do
      before do
        stub_env(GIT_CONFIG_GLOBAL: '/dev/null')
      end

      it 'returns the default value, ignoring global, respecting xdg for the default ignore dir' do
        expect(subject).to eq "#{home}/.xconfig/git/ignore"
      end
    end

    context 'with GIT_CONFIG_GLOBAL set to empty string' do
      before do
        stub_env(GIT_CONFIG_GLOBAL: '')
      end

      it 'returns the default value, ignoring global, respecting xdg for the default ignore dir' do
        expect(subject).to eq "#{home}/.xconfig/git/ignore"
      end
    end

    context 'with .gitconfig file also' do
      before do
        stub_file(config_content, path: "#{home}/.gitconfig")
      end

      it 'returns a literal unquoted value from .gitconfig for the path' do
        expect(subject).to eq "#{home}/.global_gitignore"
      end

      context 'with GIT_CONFIG_GLOBAL set to /dev/null' do
        before do
          stub_env(GIT_CONFIG_GLOBAL: '/dev/null')
        end

        it 'returns the default value, ignoring global, respecting xdg for the default ignore dir' do
          expect(subject).to eq "#{home}/.xconfig/git/ignore"
        end
      end

      context 'with GIT_CONFIG_GLOBAL set without excludesfile' do
        before do
          stub_env(GIT_CONFIG_GLOBAL: "#{home}/other_gitconfig")
          stub_file(<<~GITCONFIG, path: "#{home}/other_gitconfig")
            [core]
              attributesfile = ~/gitattributes
          GITCONFIG
        end

        it 'returns the default value, ignoring global, respecting xdg for the default ignore dir' do
          expect(subject).to eq "#{home}/.xconfig/git/ignore"
        end
      end

      context 'with GIT_CONFIG_GLOBAL set' do
        before do
          stub_env(GIT_CONFIG_GLOBAL: "#{home}/other_gitconfig")
          stub_file(<<~GITCONFIG, path: "#{home}/other_gitconfig")
            [core]
              excludesfile = ~/other_gitignore
          GITCONFIG
        end

        it 'returns a literal unquoted value for the path skipping xdg entirely' do
          expect(subject).to eq "#{home}/other_gitignore"
        end
      end
    end
  end
end
