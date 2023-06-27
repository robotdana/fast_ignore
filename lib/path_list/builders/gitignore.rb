# frozen_string_literal: true

class PathList
  module Builders
    module Gitignore
      def self.build(rule, polarity, root)
        GitignoreRuleBuilder.new(rule, root: root, polarity: polarity).build
      end

      def self.build_implicit(rule, root)
        GitignoreRuleBuilder.new(rule, root: root, polarity: :allow).build_implicit
      end
    end
  end
end
