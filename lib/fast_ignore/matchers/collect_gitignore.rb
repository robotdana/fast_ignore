# frozen_string_literal: true

class FastIgnore
  module Matchers
    class CollectGitignore < Base
      def initialize(root, format: :gitignore, append: :gitignore)
        @append = append
        @format = format
        @root = PathExpander.expand_path(root)
      end

      def weight
        -Float::INFINITY
      end

      def dir_only?
        # :nocov:
        # TODO: consistent api
        true
        # :nocov:
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

        nil
      end
    end
  end
end
