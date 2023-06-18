# frozen_string_literal: true

class PathList
  module Matchers
    class MatchUnlessDir < Wrapper
      def build(matcher)
        return matcher if matcher.is_a?(self.class)

        super
      end

      def match(candidate)
        @matcher.match(candidate) unless candidate.directory?
      end

      private

      def calculate_weight
        # arbitrary, files to directories ratio from my projects dir
        (super * 0.8) + 1
      end
    end
  end
end
