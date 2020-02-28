# frozen_string_literal: true

require_relative 'rule'
require_relative 'backports'

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
      def new_rule(rule, root:, rule_set:, allow: false, expand_path: false) # rubocop:disable Metrics/MethodLength
        rule = strip(rule)
        rule, dir_only = extract_dir_only(rule)

        return if skip?(rule)

        rule, negation = extract_negation(rule, allow)
        rule = expand_path(rule, root) if expand_path

        anchored, prefix = prefix(rule)

        rule = "#{root}#{prefix}#{rule}"

        rule_set.append_rules(
          anchored,
          rules(rule, allow, root, dir_only, negation)
        )
      end

      private

      def rules(rule, allow, root, dir_only, negation)
        rules = [::FastIgnore::Rule.new(rule, dir_only, negation)]
        return rules unless allow

        rules << ::FastIgnore::Rule.new("#{rule}/**/*", false, negation)
        parent = File.dirname(rule)
        while parent != root
          rules << ::FastIgnore::Rule.new(parent, true, true)
          parent = File.dirname(parent)
        end
        rules
      end

      def extract_negation(rule, allow)
        return [rule, allow] unless rule.start_with?('!')

        [rule[1..-1], !allow]
      end

      def extract_dir_only(rule)
        return [rule, false] unless rule.end_with?('/')

        [rule[0..-2], true]
      end

      def strip(rule)
        rule = rule.chomp
        rule = rule.rstrip unless rule.end_with?('\\ ')
        rule
      end

      def prefix(rule)
        if rule.start_with?('/')
          [true, '']
        elsif rule.end_with?('/**') || rule.include?('/**/')
          [true, '/']
        else
          [false, '/**/']
        end
      end

      def expand_path(rule, root)
        rule = ::File.expand_path(rule).delete_prefix(root) if rule.match?(%r{^(?:[~/]|\.{1,2}/)})

        rule = "/#{rule}" unless rule.start_with?('*') || rule.start_with?('/')

        rule
      end

      def skip?(rule)
        rule.empty? || rule.start_with?('#')
      end
    end
  end
end
