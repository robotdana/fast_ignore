# frozen_string_literal: true

class PathList
  module Builders
    class GlobGitignore
      def self.build(rule, polarity, root)
        GitignoreRuleBuilder.new(rule, root: root, expand_path: true, polarity: polarity).build
      end

      def self.build_implicit(rule, root)
        GitignoreRuleBuilder.new(rule, root: root, expand_path: true, polarity: :allow).build_implicit
      end
    end
  end
end
