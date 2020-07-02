# frozen_string_literal: true

class FastIgnore
  module RuleBuilder
    class << self
      # :nocov:
      using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
      # :nocov:

      def build(rule, allow, expand_path_with, file_root)
        return shebang_rules(rule, allow, file_root) if remove_shebang(rule)

        strip(rule)
        return [] if skip?(rule)

        gitignore_rules(rule, allow, expand_path_with, file_root)
      end

      private

      def strip(rule)
        rule.chomp!
        rule.sub!(/(?<!\\) +\z/, '')
      end

      def remove_shebang(rule)
        return unless rule.delete_prefix!('#!:')

        rule.strip!

        true
      end

      def shebang_rules(rule, allow, file_path)
        file_path_pattern = /\A#{::Regexp.escape(file_path)}./ if file_path && !file_path.empty?
        rule = ::FastIgnore::ShebangRule.new(/\A#!.*\b#{::Regexp.escape(rule)}\b/i, allow, file_path_pattern)
        return rule unless allow

        Array(gitignore_rules('*/'.dup, allow, nil, file_path)) + [rule]
      end

      def skip?(rule)
        rule.empty? || rule.start_with?('#')
      end

      def gitignore_rules(rule, allow, expand_path_with, file_root)
        dir_only = extract_dir_only(rule)
        negation = extract_negation(rule, allow)

        if allow
          expand_rule_path(rule, expand_path_with) if expand_path_with
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule, negation, dir_only, file_root).build
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule, negation, dir_only, file_root).build
        end
      end

      def extract_dir_only(rule)
        rule.delete_suffix!('/')
      end

      def extract_negation(rule, allow)
        return allow unless rule.delete_prefix!('!')

        not allow
      end

      EXPAND_PATH_RE = %r{(^(?:[~/]|\.{1,2}/)|/\.\./)}.freeze
      def expand_rule_path(rule, root)
        rule.replace(::File.expand_path(rule)) if rule.match?(EXPAND_PATH_RE)
        rule.delete_prefix!(root)
        rule.prepend('/') unless rule.start_with?('*')
      end
    end
  end
end
