# frozen_string_literal: true

class FastIgnore
  module Matchers
    class CollectGitignore
      def initialize(root, format: :gitignore, append: :gitignore)
        @append = append
        @format = format
        @root = PathExpander.expand_path(root)
      end

      def weight
        -Float::INFINITY
      end

      def removable?
        false
      end

      def dir_only?
        # :nocov:
        # TODO: consistent api
        true
        # :nocov:
      end

      def file_only?
        # :nocov:
        # TODO: consistent api
        false
        # :nocov:
      end

      def squashable_with?(_)
        # :nocov:
        # TODO: consistent api
        false
        # :nocov:
      end

      def implicit?
        false
      end

      def match(candidate)
        if candidate.child_or_self?(@root) && candidate.directory?
          candidate.path_list.ignore!(
            from_file: './.gitignore',
            root: candidate.full_path,
            append: @append,
            format: @format
          )
        end

        false
      end
    end
  end
end
