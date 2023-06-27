# frozen_string_literal: true

class PathList
  class Builder
    class Gitignore < Builder
      def build
        GitignoreRuleBuilder.new(@rule, root: @root, polarity: @polarity).build
      end

      def build_implicit
        GitignoreRuleBuilder.new(@rule, root: @root, polarity: :allow).build_implicit
      end
    end
  end
end
