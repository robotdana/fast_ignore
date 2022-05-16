# frozen_string_literal: true

class FastIgnore
  module Builders
    module Gitignore
      def self.build(rule, allow, _root)
        if allow
          ::FastIgnore::GitignoreIncludeRuleBuilder.new(rule).build
        else
          ::FastIgnore::GitignoreRuleBuilder.new(rule).build
        end
      end
    end
  end
end
