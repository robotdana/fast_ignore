# frozen_string_literal: true

class PathList
  module Matchers
    class CollectGitignore < Base
      def initialize(root, format: :gitignore, append: :gitignore)
        @append = append
        @format = format
        root = PathExpander.expand_path(root)
        @root_re = %r{\A#{Regexp.escape(root)}(?:\z|/)}i
        @loaded = []

        freeze
      end

      def weight
        -Float::INFINITY
      end

      def polarity
        :mixed
      end

      def dir_only?
        # :nocov:
        # TODO: new api stuff
        true
        # :nocov:
      end

      def match(candidate)
        if candidate.full_path.match?(@root_re) && candidate.directory? && !@loaded.include?(candidate.full_path)
          candidate.path_list.ignore!(
            from_file: './.gitignore',
            root: candidate.full_path,
            append: @append,
            format: @format
          )

          @loaded << candidate.full_path
        end

        :allow
      end
    end
  end
end
