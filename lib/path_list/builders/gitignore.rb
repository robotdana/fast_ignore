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

      def self.build_implicit(rule, allow, _root)
        return Matchers::Null unless allow

        GitignoreIncludeRuleBuilder.new(rule).build_implicit
      end
    end
  end
end
