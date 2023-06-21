# frozen_string_literal: true

class PathList
  module Builders
    class GlobGitignore
      def self.build(rule, allow, root)
        if allow
          GitignoreRuleBuilder.new(rule, root: root, expand_path: true, allow: true).build
        else
          GitignoreRuleBuilder.new(rule, root: root, expand_path: true, allow: false).build
        end
      end

      def self.build_implicit(rule, allow, root)
        if allow
          GitignoreRuleBuilder.new(rule, root: root, expand_path: true, allow: true).build_implicit
        else
          Matchers::Blank
        end
      end
    end
  end
end
