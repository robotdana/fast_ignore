# frozen_string_literal: true

class PathList
  module Builders
    module FullPath
      def self.build(path, allow, _root)
        path = path.delete_prefix('/')
        dir_only = path.end_with?('/')
        path.delete_suffix('/')
        m = Matchers::PathRegexp.build(/\A#{Regexp.escape(path)}\z/i, true, allow)
        Matchers::MatchIfDir.new(m) if dir_only
        m
      end

      # TODO: currently this assumes dir_only, and maybe shouldn't for the last part but should for my use case
      def self.build_implicit(path, allow, _root)
        @rule = Rule.new(
          [:start_anchor] + path
            .delete_prefix('/')
            .split('/')
            .flat_map { |x| [Regexp.escape(x), :dir] } + [:any_non_dir],
          allow
        ).build_parents
      end
    end
  end
end
