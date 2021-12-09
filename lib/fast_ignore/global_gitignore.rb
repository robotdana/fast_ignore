# frozen_string_literal: true

class FastIgnore
  module GlobalGitignore
    class << self
      def path(root:)
        ignore_path = gitconfigs_gitignore_path(root) ||
          default_global_gitignore_path

        ignore_path unless ignore_path.empty?
      end

      private

      def gitconfigs_gitignore_path(root)
        gitconfig_gitignore_path(repo_config_path(root)) ||
          gitconfig_gitignore_path(global_config_path) ||
          gitconfig_gitignore_path(default_user_config_path) ||
          gitconfig_gitignore_path(system_config_path)
      rescue ::FastIgnore::GitconfigParseError
        ''
      end

      def gitconfig_gitignore_path(config_path)
        return unless config_path
        return unless ::File.readable?(config_path)

        ignore_path = ::FastIgnore::GitconfigParser.parse(config_path)
        return unless ignore_path

        ignore_path.strip!
        return '' if ignore_path.empty? # don't expand path in this case

        ::File.expand_path(ignore_path)
      end

      def default_user_config_path
        return if env('GIT_CONFIG_GLOBAL')

        ::File.expand_path('git/config', default_config_home)
      end

      def default_global_gitignore_path
        ::File.expand_path('git/ignore', default_config_home)
      end

      def repo_config_path(root)
        ::File.expand_path('.git/config', root)
      end

      def global_config_path
        ::File.expand_path(env('GIT_CONFIG_GLOBAL', '~/.gitconfig'))
      end

      def system_config_path
        return if env?('GIT_CONFIG_NOSYSTEM')

        ::File.expand_path(env('GIT_CONFIG_SYSTEM', '/usr/local/etc/gitconfig'))
      end

      def default_config_home
        env('XDG_CONFIG_HOME', '~/.config')
      end

      def env(env_var, default = nil)
        value = ::ENV[env_var]

        if value && (not value.empty?)
          value
        else
          default
        end
      end

      def env?(env_var)
        value = ::ENV[env_var]

        if value&.match?(/\A(yes|on|true|1)\z/i)
          true
        elsif !value || value.match?(/\A(no|off|false|0|)\z/i)
          false
        else
          raise ::FastIgnore::GitconfigParseError
        end
      end
    end
  end
end
