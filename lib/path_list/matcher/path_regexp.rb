# frozen_string_literal: true

class PathList
  class Matcher
    class PathRegexp < MatchRegexp
      def match(candidate)
        @polarity if @rule.match?(candidate.full_path_downcase)
      end

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2
      end
    end
  end
end
