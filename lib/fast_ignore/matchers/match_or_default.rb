# frozen_string_literal: true

class FastIgnore
  module Matchers
    class MatchOrDefault < Wrapper
      def self.build(matcher, default)
        new(matcher, default)
      end

      def initialize(matcher, default)
        @default = default

        super(matcher)
      end

      def squashable_with?(_)
        false
      end

      def match(candidate)
        @matcher.match(candidate) || @default
      end
    end
  end
end
