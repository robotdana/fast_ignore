# frozen_string_literal: true

class FastIgnore
  class RuleParser
    # :nocov:
    if ::FastIgnore::Backports.ruby_version_less_than?(2, 5)
      require_relative 'backports/delete_prefix_suffix'
      using ::FastIgnore::Backports::DeletePrefixSuffix
    end
    # :nocov:

    # rule or nil
    class << self
      def new_rule(rule, rule_set:, allow: false, expand_path: false, file_root: nil) # rubocop:disable Metrics/MethodLength
        rule = rule.dup
        strip(rule)
        dir_only = extract_dir_only(rule)

        return if skip?(rule)

        negation = extract_negation(rule, allow)

        expand_rule_path(rule, expand_path) if expand_path
        anchored = anchored?(rule)
        rule.delete_prefix!('/')

        rule.prepend("#{file_root}#{'**/' unless anchored}") if file_root || (not anchored)

        rule.freeze

        rule_set.append_rules(
          anchored,
          rules(rule, allow, dir_only, negation)
        )
      end

      private

      DOT = '.'
      def rules(rule, allow, dir_only, negation)
        rules = [::FastIgnore::Rule.new(rule, dir_only, negation)]
        return rules unless allow

        rules << ::FastIgnore::Rule.new("#{rule}/**/*", false, negation)
        parent = File.dirname(rule)
        while parent != DOT
          rules << ::FastIgnore::Rule.new(parent.freeze, true, true)
          parent = File.dirname(parent)
        end
        rules
      end

      def extract_negation(rule, allow)
        return allow unless rule.start_with?('!')

        rule.slice!(0)

        !allow
      end

      def extract_dir_only(rule)
        return false unless rule.end_with?('/')

        rule.chop!

        true
      end

      def strip(rule)
        rule.chomp!
        rule.rstrip! unless rule.end_with?('\\ ')
      end

      def anchored?(rule)
        rule.start_with?('/') ||
          rule.end_with?('/**') ||
          rule.include?('/**/')
      end

      EXPAND_PATH_RE = %r{^(?:[~/]|\.{1,2}/)}.freeze
      def expand_rule_path(rule, root)
        rule.replace(::File.expand_path(rule)) if rule.match?(EXPAND_PATH_RE)
        rule.delete_prefix!(root)
        rule.prepend('/') unless rule.start_with?('*') || rule.start_with?('/')
      end

      def skip?(rule)
        rule.empty? || rule.start_with?('#')
      end
    end
  end
end
