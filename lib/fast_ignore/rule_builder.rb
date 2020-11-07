# frozen_string_literal: true

class FastIgnore
  module RuleBuilder
    class << self
      # :nocov:
      using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
      # :nocov:

      def build(rule, allow, expand_path_with, file_root)
        if rule.delete_prefix!('#!:')
          shebang_rules(rule, allow, file_root)
        else
          gitignore_rules(rule, allow, file_root, expand_path_with)
        end
      end

      private

      # how long can a shebang be?
      # https://www.in-ulm.de/~mascheck/various/shebang/
      # apparently cygwin 65536, and a limit is better than no limit
      def shebang_rules(shebang, allow, file_root)
        shebang.strip!
        pattern = /\A#![^\n]{,#{65_536 - shebang.length}}\b#{::Regexp.escape(shebang)}\b/i
        rule = ::FastIgnore::ShebangRule.new(pattern, allow, file_root&.shebang_path_pattern)
        return rule unless allow

        rules = gitignore_rules('*/'.dup, allow, file_root)
        rules.pop # don't want the include all children one.
        rules << rule
        rules
      end

      def gitignore_rules(rule, allow, file_root, expand_path_with = nil)
        if allow
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule, file_root, expand_path_with).build
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule, file_root).build
        end
      end
    end
  end
end
