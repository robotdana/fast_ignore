# frozen_string_literal: true

class FastIgnore
  module RuleBuilder
    class << self
      def build(rule, allow, expand_path_with)
        if rule.delete_prefix!('#!:')
          shebang_rules(rule, allow)
        else
          gitignore_rules(rule, allow, expand_path_with)
        end
      end

      private

      def shebang_rules(shebang, allow)
        shebang.strip!
        pattern = /\A#!.*\b#{::Regexp.escape(shebang)}\b/i
        rule = ::FastIgnore::ShebangRule.new(pattern, allow)
        return rule unless allow

        # also allow all directories in case they include a file with the matching shebang file
        [::FastIgnore::Rule.new(//, true, true, true), rule]
      end

      def gitignore_rules(rule, allow, expand_path_with = nil)
        if allow
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule, expand_path_with).build
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule).build
        end
      end
    end
  end
end
