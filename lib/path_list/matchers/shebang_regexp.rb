# frozen_string_literal: true

class PathList
  module Matchers
    class ShebangRegexp < MatchRegexp
      def match(candidate)
        @polarity if candidate.first_line.match?(@rule)
      end

      private

      def calculate_weight
        (@rule.inspect.length / 3.0) + 2
      end
    end
  end
end
