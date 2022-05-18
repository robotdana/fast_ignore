# frozen_string_literal: true

class FastIgnore
  module Matchers
    class MatchOrDefault
      def initialize(matcher, default)
        @matcher = matcher
        @default = default

        freeze
      end

      def weight
        @matcher.weight
      end

      def empty?
        @matcher.empty?
      end

      def match?(candidate)
        @matcher.match?(candidate) || @default
      end
    end
  end
end
