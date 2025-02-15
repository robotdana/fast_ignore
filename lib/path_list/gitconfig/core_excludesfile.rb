# frozen_string_literal: true

class PathList
  # @api private
  module Gitconfig
    # Find the configured git core.excludesFile
    module CoreExcludesfile
      class << self
        # @param git_dir [String]
        # @return [String, nil]
        def path(git_dir:)
          ignore_path = gitconfigs_core_excludesfile_path(git_dir) ||
            default_core_excludesfile_path

          ignore_path unless ignore_path.empty?
        end

        private

        def gitconfigs_core_excludesfile_path(git_dir)
          gitconfig_core_excludesfile_path(repo_config_path(git_dir), git_dir) ||
            gitconfig_core_excludesfile_path(global_config_path, git_dir) ||
            gitconfig_core_excludesfile_path(default_user_config_path, git_dir) ||
            gitconfig_core_excludesfile_path(system_config_path, git_dir)
        rescue ParseError => e
          ::Warning.warn("PathList gitconfig parser failed\n" + e.message)

          ''
        end

        def gitconfig_core_excludesfile_path(config_path, git_dir)
          return unless config_path
          return if config_path.empty?
          return if config_path == ::File::NULL
          return unless ::File.readable?(config_path)

          ignore_path = FileParser.parse(config_path, git_dir: git_dir).excludesfile
          return unless ignore_path

          ignore_path.strip!
          CanonicalPath.full_path_ignore_empty(ignore_path)
        end

        def default_user_config_path
          return if ENV['GIT_CONFIG_GLOBAL']

          CanonicalPath.full_path_from('git/config', default_config_home)
        end

        def default_core_excludesfile_path
          CanonicalPath.full_path_from('git/ignore', default_config_home)
        end

        def repo_config_path(git_dir)
          CanonicalPath.full_path_from('config', git_dir) if git_dir
        end

        def global_config_path
          CanonicalPath.full_path_ignore_empty(::ENV['GIT_CONFIG_GLOBAL'] || '~/.gitconfig')
        end

        def system_config_path
          return if env?('GIT_CONFIG_NOSYSTEM')

          CanonicalPath.full_path_ignore_empty(::ENV['GIT_CONFIG_SYSTEM'] || '/usr/local/etc/gitconfig')
        end

        def default_config_home
          value = ::ENV['XDG_CONFIG_HOME']
          return '~/.config' if !value || value.empty?

          value
        end

        def env?(env_var)
          value = ::ENV[env_var]

          if value&.match?(/\A(yes|on|true|\d+)\z/i)
            true
          elsif !value || value.match?(/\A(no|off|false|0|-\d+)\z/i)
            false
          else
            raise ParseError, "Bad boolean environment value #{value.inspect} for $#{env_var}"
          end
        end
      end
    end
  end
end
