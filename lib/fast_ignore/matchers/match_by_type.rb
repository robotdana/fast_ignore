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
        @implicit = matchers.all?(&:implicit?)
        @weight = matchers.sum(&:weight)

        freeze
      end

      def removable?
        @removable
      end

      def implicit?
        @implicit
      end

      # TODO: squashable with same class
      def squashable_with?(_)
        false
      end

      def dir_only?
        @file_matcher == Unmatchable
      end

      def file_only?
        @dir_matcher == Unmatchable
      end

      def match(candidate)
        if candidate.directory?
          @dir_matcher.match(candidate)
        else
          @file_matcher.match(candidate)
        end
      end
    end
  end
end
