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
        parent_matcher = build_parent_matcher
        return build_child_matcher unless parent_matcher

        Matchers::Any.build([parent_matcher, build_child_matcher])
      end

      private

      def build_parent_matcher
        ancestors = RegexpBuilder.new_from_path(@path).ancestors
        return if ancestors.empty?

        Matchers::PathRegexp.build(ancestors, :allow)
      end

      def build_child_matcher
        Matchers::PathRegexp.build(RegexpBuilder.new_from_path(@path, dir: nil), :allow)
      end
    end
  end
end
