# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      class << self
        def build(path, allow, root)
          Matchers::ExactString.new(PathExpander.expand_path(path, root), allow ? :allow : :ignore)
        end

        def build_implicit(path, _allow, root)
          path = PathExpander.expand_path(path, root)
          parent_matcher = build_parent_matcher(path)
          return build_child_matcher(path) unless parent_matcher

          Matchers::Any.build([parent_matcher, build_child_matcher(path)])
        end

        private

        def build_parent_matcher(path)
          ancestors = RegexpBuilder.new_from_path(path).ancestors
          return if ancestors.empty?

          Matchers::PathRegexp.build(ancestors, true)
        end

        def build_child_matcher(path)
          Matchers::PathRegexp.build(RegexpBuilder.new_from_path(path, dir: nil), true)
        end
      end
    end
  end
end
