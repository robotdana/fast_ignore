# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < MatchRegexp
      def match(candidate)
        @polarity if @rule.match?(candidate.path)
      end

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2
      end
    end
  end
end
