# frozen_string_literal: true

class PathList
  module Builders
    module Gitignore
      def self.build(rule, allow, root)
        if allow
          GitignoreRuleBuilder.new(rule, root: root, allow: true).build
        else
          GitignoreRuleBuilder.new(rule, root: root, allow: false).build
        end
      end

      def self.build_implicit(rule, allow, root)
        return Matchers::Blank unless allow

        GitignoreRuleBuilder.new(rule, root: root, allow: true).build_implicit
      end
    end
  end
end
