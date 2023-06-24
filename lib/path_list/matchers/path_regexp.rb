# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < MatchRegexp
      def match(candidate)
        @polarity if @rule.match?(candidate.full_path)
      end

      def compress_self
        return self if @re_builder.compressed?

        self.class.build(@re_builder.compress, @polarity == :allow)
      end

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2
      end
    end
  end
end
