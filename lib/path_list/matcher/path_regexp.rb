# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class PathRegexp < MatchRegexp
      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @polarity if @regexp.match?(candidate.full_path_downcase)
      end

      private

      def calculate_weight
        # chaos guesses
        (@regexp.inspect.length / 4.0) + 2
      end
    end
  end
end
