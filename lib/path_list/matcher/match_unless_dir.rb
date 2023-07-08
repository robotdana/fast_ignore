# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class MatchUnlessDir < Wrapper
      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @matcher.match(candidate) unless candidate.directory?
      end

      # @param (see Matcher#dir_matcher)
      # @return (see Matcher#dir_matcher)
      def dir_matcher
        Blank
      end

      # @param (see Matcher#file_matcher)
      # @return (see Matcher#file_matcher)
      def file_matcher
        @matcher.file_matcher
      end

      private

      def calculate_weight
        # arbitrary, files to directories ratio from my projects dir
        (super * 0.8) + 1
      end
    end
  end
end
