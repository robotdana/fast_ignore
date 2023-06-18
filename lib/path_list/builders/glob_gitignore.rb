# frozen_string_literal: true

class PathList
  module Builders
    module GlobGitignore
      def self.build(rule, allow, root)
        if allow
          GitignoreIncludeRuleBuilder.new(rule, expand_path_with: root).build
        else
          GitignoreRuleBuilder.new(rule, expand_path_with: root).build
        end
      end

      def self.build_implicit(rule, allow, root)
        if allow
          GitignoreIncludeRuleBuilder.new(rule, expand_path_with: root).build_implicit
        else
          Matchers::Blank
        end
      end
    end
  end
end
