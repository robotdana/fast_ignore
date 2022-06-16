# frozen_string_literal: true

class FastIgnore
  module Matchers
    class MatchByType
      attr_reader :weight

      def initialize(matchers)
        dir_matchers = matchers.reject(&:file_only?)
        file_matchers = matchers.reject(&:dir_only?)

        @dir_matcher = dir_matchers.empty? ? Unmatchable : LastMatch.new(dir_matchers)
        @file_matcher = file_matchers.empty? ? Unmatchable : LastMatch.new(file_matchers)

        @removable = matchers.empty? || matchers.all?(&:removable?)
        @weight = matchers.sum(&:weight)

        freeze
      end

      def removable?
        @removable
      end

      # TODO: squashable with same class
      def squashable_with?(other)
        other == Unmatchable
      end

      def squash(_)
        self
      end

      def dir_only?
        @file_matcher == Unmatchable
      end

      def file_only?
        @dir_matcher == Unmatchable
      end

      def match?(candidate)
        if candidate.directory?
          @dir_matcher.match?(candidate)
        else
          @file_matcher.match?(candidate)
        end
      end
    end
  end
end
