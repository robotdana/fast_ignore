# frozen_string_literal: true

class FastIgnore
  module Matchers
    class CollectGitignore < Base
      def initialize(root, format: :gitignore, append: :gitignore)
        @append = append
        @format = format
        root = PathExpander.expand_path(root)
        @root_re = %r{\A#{Regexp.escape(root)}(?:\z|/)}i
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
        if candidate.full_path.match?(@root_re) && candidate.directory?
          candidate.path_list.ignore!(
            from_file: './.gitignore',
            root: candidate.full_path,
            append: @append,
            format: @format
          )
        end

        :allow
      end
    end
  end
end
