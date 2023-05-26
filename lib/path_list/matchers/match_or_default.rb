# frozen_string_literal: true

class PathList
  module Matchers
    class MatchOrDefault < Wrapper
      def initialize(matcher, default)
        @default = default

        super(matcher)
      end

      def squashable_with?(other)
        self == other
      end

      def squash(_)
        self
      end

      def match(candidate)
        @matcher.match(candidate) || @default
      end

      private

      def new_with_matcher(matcher)
        self.class.new(matcher, @default)
      end
    end
  end
end
