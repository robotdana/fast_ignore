# frozen_string_literal: true

class PathList
  module Builders
    module Gitignore
      def self.build(rule, allow, root)
        GitignoreRuleBuilder.new(rule, root: root, allow: allow).build
      end

      def self.build_implicit(rule, allow, root)
        return Matchers::Blank unless allow

        GitignoreRuleBuilder.new(rule, root: root, allow: true).build_implicit
      end
    end
  end
end
