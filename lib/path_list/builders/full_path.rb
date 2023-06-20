# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build(path, allow, _root)
        path = path.delete_prefix('/')
        path.delete_suffix('/')
        re = PathRegexpBuilder.new([:start_anchor, Regexp.escape(path), :end_anchor])
        Matchers::MatchIfDir.new(re.build_path_matcher(allow))
      end

      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build_implicit(path, allow, _root)
        Matchers::MatchIfDir.new(
          PathRegexpBuilder.new(
            [:start_anchor] + path
              .delete_prefix('/')
              .split('/')
              .flat_map { |x| [Regexp.escape(x), :dir] } + [:any_non_dir]
          ).build_parents(allow)
        )
      end
    end
  end
end
