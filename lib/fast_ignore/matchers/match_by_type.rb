# frozen_string_literal: true

class FastIgnore
  module Matchers
    class MatchByType
      def self.build_from_list(matchers)
        dir_matchers = matchers.reject(&:file_only?)
        file_matchers = matchers.reject(&:dir_only?)

        # return list_class.new(matchers) if dir_matchers == file_matchers

        dir_matcher = dir_matchers.empty? ? Unmatchable : LastMatch.build(dir_matchers)
        file_matcher = file_matchers.empty? ? Unmatchable : LastMatch.build(file_matchers)

        new(file_matcher, dir_matcher)
      end

      def initialize(file_matcher, dir_matcher)
        @dir_matcher = dir_matcher
        @file_matcher = file_matcher

        freeze
      end

      def removable?
        (@dir_matcher.removable? && @file_matcher.removable?) ||
          (@dir_matcher == Unmatchable && @file_matcher == Unmatchable)
      end

      def implicit?
        @dir_matcher.implicit? && @file_matcher.implicit?
      end

      def weight
        [@dir_matcher.weight, @file_matcher.weight].max
      end

      # TODO: squashable with same class
      def squashable_with?(_)
        false
      end

      def dir_only?
        # :nocov:
        # TODO: consistent api
        @file_matcher == Unmatchable
        # :nocov:
      end

      def file_only?
        # :nocov:
        # TODO: consistent api
        @dir_matcher == Unmatchable
        # :nocov:
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
