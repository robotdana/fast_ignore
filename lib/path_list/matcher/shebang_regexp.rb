# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class ShebangRegexp < MatchRegexp
      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @polarity if candidate.shebang.match?(@regexp)
      end

      private

      def calculate_weight
        (@regexp.inspect.length / 3.0) + 2
      end
    end
  end
end
