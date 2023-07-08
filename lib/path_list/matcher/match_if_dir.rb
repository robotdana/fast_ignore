# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class MatchIfDir < Wrapper
      # @param (see Wrapper.build)
      # @return (see Wrapper.build)
      def self.build(matcher)
        return AllowAnyDir if matcher == Allow

        super
      end

      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @matcher.match(candidate) if candidate.directory?
      end

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      def squashable_with?(other)
        other.equal?(AllowAnyDir) || super
      end

      # @param (see Matcher#squash)
      # @return (see Matcher#squash)
      def squash(list, preserve_order)
        if preserve_order
          self.class.build(LastMatch.build(list.map { |l| l == AllowAnyDir ? Allow : l.matcher }))
        elsif list.include?(AllowAnyDir)
          AllowAnyDir
        else
          self.class.build(Any.build(list.map(&:matcher)))
        end
      end

      # @return (see Matcher#dir_matcher)
      def dir_matcher
        @matcher.dir_matcher
      end

      # @return (see Matcher#file_matcher)
      def file_matcher
        Blank
      end

      # @return [PathList::Matcher]
      attr_reader :matcher

      private

      def calculate_weight
        # arbitrary, files to directories ratio from my projects dir
        (super * 0.2) + 1
      end
    end
  end
end
