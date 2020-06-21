# frozen_string_literal: true

class FastIgnore
  module RuleBuilder
    class << self
      # :nocov:
      using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
      # :nocov:

      def build(rule, allow, expand_path_with, file_root)
        return shebang_rules(rule, allow) if remove_shebang(rule)

        strip(rule)
        return [] if skip?(rule)

        gitignore_rules(rule, allow, expand_path_with, file_root)
      end

      private

      def strip(rule)
        rule.chomp!
        rule.rstrip! unless rule.end_with?('\\ ')
      end

      def remove_shebang(rule)
        return unless rule.delete_prefix!('#!:')

        rule.strip!

        true
      end

      def shebang_rules(rule, allow)
        rule = ::FastIgnore::ShebangRule.new(/\A#!.*\b#{Regexp.escape(rule)}\b/i, allow)
        return rule unless allow

        [::FastIgnore::Rule.new(//, true, true, true), rule]
      end

      def skip?(rule)
        rule.empty? || rule.start_with?('#')
      end

      def gitignore_rules(rule, allow, expand_path_with, file_root)
        dir_only = extract_dir_only(rule)
        negation = extract_negation(rule, allow)

        expand_rule_path(rule, expand_path_with) if expand_path_with

        ::FastIgnore::GitignoreRuleBuilder.build(rule, negation, dir_only, file_root, allow)
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
