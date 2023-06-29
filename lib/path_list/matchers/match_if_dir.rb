# frozen_string_literal: true

class PathList
  module Matchers
    class MatchIfDir < Wrapper
      def self.build(matcher)
        return AllowAnyDir if matcher == Allow

        super
      end

      def match(candidate)
        @matcher.match(candidate) if candidate.directory?
      end

      def squashable_with?(other)
        (@polarity == :allow && other == AllowAnyDir) || super
      end

      def squash(list)
        return AllowAnyDir if list.include?(AllowAnyDir)

        super
      end

      def dir_matcher
        @matcher
      end

      def file_matcher
        Blank
      end

      private

      def calculate_weight
        # arbitrary, files to directories ratio from my projects dir
        (super * 0.2) + 1
      end
    end
  end
end
