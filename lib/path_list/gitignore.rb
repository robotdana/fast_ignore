# frozen_string_literal: true

class PathList
  module Gitignore
    class << self
      def build(root:, index: true, config: true, indexes_array: [])
        root = PathExpander.expand_path_pwd(root || '.')

        build_index_matcher(root, index, indexes_array) || build_and_append_to_collecting_matcher(root, config)
      end

      private

      def build_index_matcher(root, index, indexes_array)
        return unless index && ::File.exist?(PathExpander.expand_path('.git/index', root))

        git_index = Matchers::GitIndex.new(root)
        indexes_array << git_index
        git_index
      end

      def build_and_append_to_collecting_matcher(root, config)
        collector = build_collector(root)
        append_to_collector(collector, root, config)

        Matchers::LastMatch.build([
          Matchers::Allow,
          collector,
          build_dot_git_matcher
        ])
      end

      def append_to_collector(collector, root, config)
        if config
          global_gitignore = GlobalGitignore.path(root: root)
          collector.append(PathExpander.expand_path(global_gitignore, root), root: root) if global_gitignore
        end

        collector.append(PathExpander.expand_path('.git/info/exclude', root), root: root)
        collector.append(PathExpander.expand_path('.gitignore', root), root: root)
      end

      def build_dot_git_matcher
        Matchers::MatchIfDir.new(
          Matchers::PathRegexp.build([[:dir, '.git', :end_anchor]], :ignore)
        )
      end

      def build_collector(root)
        root_re = PathRegexp.new_from_path(root)
        root_re_children = root_re.dup
        root_re_children.replace_end :dir

        Matchers::CollectGitignore.build(
          Matchers::MatchIfDir.new(
            Matchers::PathRegexp.build([root_re_children.parts, root_re.parts], :allow)
          )
        )
      end
    end
  end
end
