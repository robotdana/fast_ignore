# frozen_string_literal: true

class FastIgnore
  module RuleBuilder
    class << self
      # :nocov:
      using ::FastIgnore::Backports::DeletePrefixSuffix if defined?(::FastIgnore::Backports::DeletePrefixSuffix)
      # :nocov:

      def build(rule, allow, format, root)
        if rule.delete_prefix!('#!:')
          shebang_rules(rule, allow)
        else
          gitignore_rules(rule, allow, format, root)
        end
      end

      private

      # how long can a shebang be?
      # https://www.in-ulm.de/~mascheck/various/shebang/
      # Theoretically the limit is 65536, but that feels utterly unreasonable
      def shebang_rules(shebang, allow)
        shebang.strip!
        pattern = /\A#![^\n]{,#{510 - shebang.length}}\b#{::Regexp.escape(shebang)}\b/i
        rule = ::FastIgnore::Matchers::ShebangRegexp.new(pattern, allow)
        return rule unless allow

        # also allow all directories in case they include a file with the matching shebang file
        [::FastIgnore::Matchers::AllowAnyDir, rule]
      end

      def gitignore_rules(rule, allow, format, root)
        if allow
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule, expand_path_with: (root if format == :expand_path)).build
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule).build
        end
      end
    end
  end
end
