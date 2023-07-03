# frozen_string_literal: true

class PathList
  class Matcher
    class MatchIfDir < Wrapper
      def self.build(matcher)
        return AllowAnyDir if matcher == Allow

        super
      end

      def match(candidate)
        @matcher.match(candidate) if candidate.directory?
      end

      def squashable_with?(other)
        other.equal?(AllowAnyDir) || super
      end

      def squash(list, preserve_order)
        if preserve_order
          self.class.build(LastMatch.build(list.map { |l| l == AllowAnyDir ? Allow : l.matcher }))
        elsif list.include?(AllowAnyDir)
          AllowAnyDir
        else
          self.class.build(Any.build(list.map(&:matcher)))
        end
      end

      def dir_matcher
        @matcher.dir_matcher
      end

      def file_matcher
        Blank
      end

      attr_reader :matcher

      private

      def calculate_weight
        # arbitrary, files to directories ratio from my projects dir
        (super * 0.2) + 1
      end
    end
  end
end
