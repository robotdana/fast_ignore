# frozen_string_literal: true

class FastIgnore
  module RuleSetBuilder
    class << self
      # :nocov:
      using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
      # :nocov:

      def build( # rubocop:disable Metrics/ParameterLists
        root:,
        ignore_rules: nil,
        ignore_files: nil,
        gitignore: :auto,
        include_rules: nil,
        include_files: nil,
        argv_rules: nil
      )
        prepare [
          from_array(ignore_rules),
          *from_files(ignore_files, project_root: root),
          from_array('.git'),
          from_gitignore_arg(gitignore, project_root: root),
          from_array(include_rules, allow: true),
          *from_files(include_files, allow: true, project_root: root),
          from_array(argv_rules, allow: true, expand_path: root)
        ]
      end

      def append_gitignore(rule_sets, project_root:, relative_path:, soft: true)
        new_gitignore = from_file(relative_path, project_root: project_root, gitignore: true, soft: soft)
        return unless new_gitignore

        base_gitignore = rule_sets.find(&:gitignore?)
        if base_gitignore
          base_gitignore << new_gitignore
        else
          rule_sets << new_gitignore
          prepare(rule_sets)
        end
      end

      private

      def prepare(rule_sets)
        rule_sets.compact!
        rule_sets.reject!(&:empty?)
        rule_sets.sort_by!(&:weight)
        rule_sets
      end

      def from_file(filename, project_root:, allow: false, file_root: nil, gitignore: false, soft: false) # rubocop:disable Metrics/ParameterLists
        filename = ::File.expand_path(filename, project_root)
        return if soft && !::File.exist?(filename)
        unless file_root || filename.start_with?(project_root)
          raise FastIgnore::Error, "#{filename} is not within #{project_root}"
        end

        file_root ||= "#{::File.dirname(filename)}/".delete_prefix(project_root)
        build_rule_set(::File.readlines(filename), allow, file_root: file_root, gitignore: gitignore)
      end

      def from_files(files, project_root:, allow: false)
        Array(files).map do |file|
          from_file(file, project_root: project_root, allow: allow)
        end
      end

      def from_gitignore_arg(gitignore, project_root:)
        return unless gitignore

        gi = ::FastIgnore::RuleSet.new([], false, true)
        gi << from_gitignore_file(gitconfig_global_gitignore_path || default_global_gitignore_path)
        gi << from_gitignore_file(::File.join(project_root, '.git/info/exclude'))
        gi << from_gitignore_file(::File.join(project_root, '.gitignore'), soft: gitignore == :auto)
        gi
      end

      def from_gitignore_file(path, soft: true)
        return if soft && !::File.exist?(path)

        build_rule_set(::File.readlines(path), false, file_root: '', gitignore: true)
      end

      def gitconfig_global_gitignore_path
        config_path = ::File.expand_path('~/.gitconfig')
        return unless ::File.exist?(config_path)

        ignore_path = ::File.readlines(config_path).find { |l| l.start_with?("\texcludesfile = ") }
        return unless ignore_path

        ignore_path.delete_prefix!("\texcludesfile = ")
        ignore_path.strip!
        ::File.expand_path(ignore_path)
      end

      def default_global_gitignore_path
        if ENV['XDG_CONFIG_HOME'] && !ENV['XDG_CONFIG_HOME'].empty?
          ::File.expand_path('git/ignore', ENV['XDG_CONFIG_HOME'])
        else
          ::File.expand_path('~/.config/git/ignore')
        end
      end

      def from_array(rules, allow: false, expand_path: false)
        return unless rules

        rules = Array(rules)

        return if rules.empty?

        rules = rules.flat_map { |string| string.to_s.lines }

        build_rule_set(rules, allow, expand_path: expand_path)
      end

      def build_rule_set(rules, allow, expand_path: false, file_root: nil, gitignore: false)
        rules = rules.flat_map do |rule|
          ::FastIgnore::RuleBuilder.build(rule, allow, expand_path, file_root)
        end

        ::FastIgnore::RuleSet.new(rules, allow, gitignore)
      end
    end
  end
end
