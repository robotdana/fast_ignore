# frozen_string_literal: true

class FastIgnore
  module Builders
    module Gitignore
      def self.build(rule, allow, expand_path_with: nil)
        if allow
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule, expand_path_with: expand_path_with).build
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule, expand_path_with: expand_path_with).build
        end
      end
    end
  end
end
