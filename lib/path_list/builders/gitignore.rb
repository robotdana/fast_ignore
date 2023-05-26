# frozen_string_literal: true

class PathList
  module Builders
    module Gitignore
      def self.build(rule, allow, _root)
        if allow
          GitignoreIncludeRuleBuilder.new(rule).build
        else
          GitignoreRuleBuilder.new(rule).build
        end
      end
    end
  end
end
