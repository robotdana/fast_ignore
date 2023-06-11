# frozen_string_literal: true

class PathList
  module Matchers
    class AccumulateFromFile < Base
      def initialize(from_file, format: :gitignore, append: :gitignore)
        @append = append
        @format = format
        @from_file = from_file
        @loaded = []

        freeze
      end

      def weight
        -Float::INFINITY
      end

      def polarity
        :mixed
      end

      def match(candidate)
        if !@loaded.include?(candidate.full_path)
          candidate.path_list.ignore!(
            from_file: @from_file,
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
