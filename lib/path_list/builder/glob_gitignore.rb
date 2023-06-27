# frozen_string_literal: true

class PathList
  class Builder
    class GlobGitignore < Builder
      def build
        GitignoreRuleBuilder.new(@rule, root: @root, expand_path: true, polarity: @polarity).build
      end

      def build_implicit
        GitignoreRuleBuilder.new(@rule, root: @root, expand_path: true, polarity: :allow).build_implicit
      end
    end
  end
end
