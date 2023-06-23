# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build(path, allow, root)
        Matchers::MatchIfDir.build(
          Matchers::PathRegexp.build(
            RegexpBuilder.new_from_path(PathExpander.expand_path(path, root)),
            allow
          )
        )
      end

      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build_implicit(path, allow, root)
        ancestors = RegexpBuilder.new_from_path(PathExpander.expand_path(path, root), [:dir, :any_non_dir]).ancestors
        return Matchers::Blank if ancestors.empty?

        Matchers::MatchIfDir.build(Matchers::PathRegexp.build(ancestors, allow))
      end
    end
  end
end
