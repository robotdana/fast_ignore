# frozen_string_literal: true

class FastIgnore
  module RuleBuilder
    # rule or nil
    class << self
      # :nocov:
      if ::FastIgnore::Backports.ruby_version_less_than?(2, 5)
        require_relative 'backports/delete_prefix_suffix'
        using ::FastIgnore::Backports::DeletePrefixSuffix
      end
      # :nocov:

      def build(rule, allow, expand_path, file_root)
        strip(rule)

        return shebang_rules(rule, allow) if remove_shebang(rule)
        return [] if skip?(rule)

        gitignore_rules(rule, allow, expand_path, file_root)
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
        rules = [::FastIgnore::Rule.new(nil, true, false, allow, /\A#!.*\b#{Regexp.escape(rule)}\b/)]
        return rules unless allow

        rules << ::FastIgnore::Rule.new('**/*', true, true, true)
        rules
      end

      def skip?(rule)
        rule.empty? || rule.start_with?('#')
      end

      def gitignore_rules(rule, allow, expand_path, file_root)
        dir_only = extract_dir_only(rule)
        negation = extract_negation(rule, allow)

        expand_rule_path(rule, expand_path) if expand_path
        unanchored = unanchored?(rule)
        rule.delete_prefix!('/')

        rule.prepend("#{file_root}#{'**/' if unanchored}") if file_root || unanchored

        build_gitignore_rules(rule, unanchored, allow, dir_only, negation)
      end

      def extract_dir_only(rule)
        rule.delete_suffix!('/')
      end

      def extract_negation(rule, allow)
        return allow unless rule.delete_prefix!('!')

        not allow
      end

      EXPAND_PATH_RE = %r{^(?:[~/]|\.{1,2}/)}.freeze
      def expand_rule_path(rule, root)
        rule.replace(::File.expand_path(rule)) if rule.match?(EXPAND_PATH_RE)
        rule.delete_prefix!(root)
        rule.prepend('/') unless rule.start_with?('*') || rule.start_with?('/')
      end

      def unanchored?(rule)
        not rule.include?('/') # we've already removed the trailing '/' with extract_dir_only
      end

      def build_gitignore_rules(rule, unanchored, allow, dir_only, negation)
        rules = [::FastIgnore::Rule.new(rule, unanchored, dir_only, negation)]
        return rules unless allow

        rules << ::FastIgnore::Rule.new("#{rule}/**/*", unanchored, false, negation)
        rules + ancestor_rules(rule, unanchored)
      end

      def ancestor_rules(parent, unanchored)
        ancestor_rules = []

        while (parent = ::File.dirname(parent)) != '.'
          rule = ::File.basename(parent) == '**' ? "#{parent}/*" : parent.freeze
          ancestor_rules << ::FastIgnore::Rule.new(rule, unanchored, true, true)
        end

        ancestor_rules
      end
    end
  end
end
