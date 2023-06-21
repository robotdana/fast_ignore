# frozen_string_literal: true

class PathList
  module Builders
    module Gitignore
      def self.build(rule, allow, _root)
        if allow
          GitignoreRuleBuilder.new(rule, allow: true).build
        else
          GitignoreRuleBuilder.new(rule, allow: false).build
        end
      end

      def self.build_implicit(rule, allow, _root)
        return Matchers::Blank unless allow

        GitignoreRuleBuilder.new(rule, allow: true).build_implicit
      end
    end
  end
end
