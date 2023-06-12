# frozen_string_literal: true

class PathList
  module Matchers
    class AccumulateFromFile < Base
      def initialize(from_file, label:, format: :gitignore)
        @label = label
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
        unless @loaded.include?(candidate.full_path)
          candidate.path_list.append!(
            from_file: @from_file,
            root: candidate.full_path,
            label: @label,
            format: @format
          )

          @loaded << candidate.full_path
        end

        :allow
      end
    end
  end
end
