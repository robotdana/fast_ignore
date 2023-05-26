# frozen_string_literal: true

class PathList
  module Builders
    module GlobGitignore
      def self.build(rule, allow, root)
        if allow
          GitignoreIncludeRuleBuilder.new(rule, expand_path_with: root).build
        # :nocov:
        else
          GitignoreRuleBuilder.new(rule, expand_path_with: root).build
          # :nocov:
        end
      end
    end
  end
end
