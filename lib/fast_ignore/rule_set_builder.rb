# frozen_string_literal: true

class FastIgnore
  module RuleSetBuilder
    class << self
      # :nocov:
      if ::FastIgnore::Backports.ruby_version_less_than?(2, 5)
        require_relative 'backports/delete_prefix_suffix'
        using ::FastIgnore::Backports::DeletePrefixSuffix
      end
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

      private

      def prepare(rule_sets)
        rule_sets.compact!
        rule_sets.reject!(&:empty?)
        rule_sets.sort_by!(&:weight)
        rule_sets
      end

      def from_file(filename, project_root:, allow: false)
        filename = ::File.expand_path(filename, project_root)
        raise FastIgnore::Error, "#{filename} is not within #{project_root}" unless filename.start_with?(project_root)

        file_root = "#{::File.dirname(filename)}/".delete_prefix(project_root)
        build_rule_set(::File.readlines(filename), allow, file_root: file_root)
      end

      def from_files(files, project_root:, allow: false)
        Array(files).map do |file|
          from_file(file, project_root: project_root, allow: allow)
        end
      end

      def from_gitignore_arg(gitignore, project_root:)
        default_path = ::File.join(project_root, '.gitignore')
        case gitignore
        when :auto
          from_file(default_path, project_root: project_root) if ::File.exist?(default_path)
        when true
          from_file(default_path, project_root: project_root)
        end
      end

      def from_array(rules, allow: false, expand_path: false)
        return unless rules

        rules = Array(rules)

        return if rules.empty?

        rules = rules.flat_map { |string| string.to_s.lines }

        build_rule_set(rules, allow, expand_path: expand_path)
      end

      def build_rule_set(rules, allow, expand_path: false, file_root: nil)
        rules = rules.flat_map do |rule|
          ::FastIgnore::RuleBuilder.build(rule, allow, expand_path, file_root)
        end

        ::FastIgnore::RuleSet.new(rules, allow).freeze
      end
    end
  end
end
