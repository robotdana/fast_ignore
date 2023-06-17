# frozen_string_literal: true

class PathList
  module Matchers
    class AccumulateFromFile < Base
      def initialize(from_file, appendable_matcher:, format: :gitignore, label: nil)
        @appendable_matcher = appendable_matcher
        @format = format
        @from_file = from_file
        @label = label

        freeze
      end

      # TODO: avoid this hack to sort things to the front.
      # it's misleading

      def weight
        -Float::INFINITY
      end

      def inspect
        super("#{@from_file} @label=#{@label} @format=#{@format}")
      end

      def polarity
        :mixed
      end

      def match(candidate)
        @appendable_matcher.append(
          Patterns.new(
            from_file: @from_file,
            root: candidate.full_path,
            format: @format,
            label: @label
          )
        )

        :allow
      end
    end
  end
end