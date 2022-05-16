# frozen_string_literal: true

class FastIgnore
  module Builders
    module ExpandPathGitignore
      def self.build(rule, allow, root)
        if allow
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule, expand_path_with: root).build
        # :nocov:
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule, expand_path_with: root).build
          # :nocov:
        end
      end
    end
  end
end
