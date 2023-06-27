# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      class << self
        def build(path, polarity, root)
          Matchers::ExactString.new(PathExpander.expand_path(path, root), polarity)
        end

        def build_implicit(path, root)
          path = PathExpander.expand_path(path, root)
          parent_matcher = build_parent_matcher(path)
          return build_child_matcher(path) unless parent_matcher

          Matchers::Any.build([parent_matcher, build_child_matcher(path)])
        end

        private

        def build_parent_matcher(path)
          ancestors = RegexpBuilder.new_from_path(path).ancestors
          return if ancestors.empty?

          Matchers::PathRegexp.build(ancestors, :allow)
        end

        def build_child_matcher(path)
          Matchers::PathRegexp.build(RegexpBuilder.new_from_path(path, dir: nil), :allow)
        end
      end
    end
  end
end
