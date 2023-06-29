# frozen_string_literal: true

class PathList
  class Builder
    class ExactPath < Builder
      def initialize(rule, polarity, root) # rubocop:disable Lint/MissingSuper
        @path = PathExpander.expand_path(rule, root)
        @polarity = polarity
      end

      def build
        Matchers::ExactString.new(@path, @polarity)
      end

      def build_implicit
        @path_re = RegexpBuilder.new_from_path(@path)
        parent_matcher = build_parent_matcher
        return build_child_matcher unless parent_matcher

        Matchers::Any.build([parent_matcher, build_child_matcher])
      end

      private

      def build_parent_matcher
        ancestors = @path_re.ancestors
        return if ancestors.empty?

        Matchers::PathRegexp.build(ancestors, :allow)
      end

      def build_child_matcher
        @child_re = @path_re.dup
        @child_re.replace_tail(:dir)
        Matchers::PathRegexp.build(@child_re, :allow)
      end
    end
  end
end
