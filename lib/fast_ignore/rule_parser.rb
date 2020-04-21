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
      def new_rule(rule, rule_set:, allow: false, expand_path: false, file_root: nil) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        rule = rule.dup
        strip(rule)

        return rule_set.append_rules(false, shebang_rules(rule, allow)) if extract_shebang(rule)

        return if skip?(rule)

        dir_only = extract_dir_only(rule)
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

      def shebang_rules(rule, allow)
        rules = [::FastIgnore::Rule.new(nil, false, true, allow, /\A#!.*\b#{Regexp.escape(rule)}\b/)]
        return rules unless allow

        rules << ::FastIgnore::Rule.new('**/*', true, false, true)
        rules
      end

      def rules(rule, allow, dir_only, negation)
        rules = [::FastIgnore::Rule.new(rule, dir_only, false, negation)]
        return rules unless allow

        rules << ::FastIgnore::Rule.new("#{rule}/**/*", false, false, negation)
        rules + ancestor_rules(rule)
      end

      def ancestor_rules(parent)
        ancestor_rules = []

        while (parent = ::File.dirname(parent)) != '.'
          rule = ::File.basename(parent) == '**' ? "#{parent}/*" : parent.freeze
          ancestor_rules << ::FastIgnore::Rule.new(rule, true, false, true)
        end

        ancestor_rules
      end

      def extract_negation(rule, allow)
        return allow unless rule.delete_prefix!('!')

        not allow
      end

      def extract_dir_only(rule)
        rule.delete_suffix!('/')
      end

      def strip(rule)
        rule.chomp!
        rule.rstrip! unless rule.end_with?('\\ ')
      end

      def anchored?(rule)
        rule.include?('/') # we've already removed the trailing '/' with extract_dir_only
      end

      EXPAND_PATH_RE = %r{^(?:[~/]|\.{1,2}/)}.freeze
      def expand_rule_path(rule, root)
        rule.replace(::File.expand_path(rule)) if rule.match?(EXPAND_PATH_RE)
        rule.delete_prefix!(root)
        rule.prepend('/') unless rule.start_with?('*') || rule.start_with?('/')
      end

      def extract_shebang(rule)
        rule.delete_prefix!('#!:') && (rule.strip! || true)
      end

      def skip?(rule)
        rule.empty? || rule.start_with?('#')
      end
    end
  end
end
