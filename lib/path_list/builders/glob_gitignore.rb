# frozen_string_literal: true

class PathList
  module Builders
    class GlobGitignore
      def self.build(rule, allow, root)
        GitignoreRuleBuilder.new(rule, root: root, expand_path: true, allow: allow).build
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
