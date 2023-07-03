# frozen_string_literal: true

class PathList
  module Gitignore
    class << self
      def build(root:, config: true)
        root = PathExpander.expand_path_pwd(root || '.')
        collector = build_collector(root)

        append(collector, root, GlobalGitignore.path(root: root)) if config
        append(collector, root, '.git/info/exclude')
        append(collector, root, '.gitignore')

        Matcher::LastMatch.build([Matcher::Allow, collector, build_dot_git_matcher])
      end

      private

      def append(collector, root, path)
        return unless path

        collector.append(PathExpander.expand_path(path, root), root: root)
      end

      def build_dot_git_matcher
        Matcher::MatchIfDir.new(
          Matcher::PathRegexp.build([[:dir, '.git', :end_anchor]], :ignore)
        )
      end

      def build_collector(root)
        root_re = PathRegexp.new_from_path(root)
        root_re_children = root_re.dup
        root_re_children.replace_end :dir

        Matcher::CollectGitignore.build(
          Matcher::MatchIfDir.new(
            Matcher::PathRegexp.build([root_re_children.parts, root_re.parts], :allow)
          )
        )
      end
    end
  end
end
