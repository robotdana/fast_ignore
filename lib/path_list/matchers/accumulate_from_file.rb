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

      # def squashable_with?(_)
      #   false
      # end

      # TODO: avoid this hack to sort things to the front.
      # it's misleading

      def weight
        -Float::INFINITY
      end

      def inspect
        "#{self.class}.new(#{@from_file.inspect}, " \
          "format: #{@format.inspect}, " \
          "label: #{@label.inspect}, " \
          'appendable_matcher: ...' \
          ')'
      end

      def polarity
        :allow
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
