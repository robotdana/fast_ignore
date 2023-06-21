# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build(path, allow, root)
        re = RegexpBuilder.new([:start_anchor, Regexp.escape(PathExpander.expand_path(path, root)), :end_anchor])
        Matchers::MatchIfDir.build(Matchers::PathRegexp.build(re, allow))
      end

      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build_implicit(path, allow, root)
        ancestors = RegexpBuilder.new(
          [:start_anchor, :dir] + Regexp.escape(PathExpander.expand_path(path, root))
            .delete_prefix('/')
            .split('/')
            .flat_map { |x| [Regexp.escape(x), :dir] } + [:any_non_dir]
        ).ancestors.each(&:compress)
        return Matchers::Blank if ancestors.empty?

        Matchers::MatchIfDir.build(
          Matchers::PathRegexp.build(RegexpBuilder.union(ancestors), allow)
        )
      end
    end
  end
end
