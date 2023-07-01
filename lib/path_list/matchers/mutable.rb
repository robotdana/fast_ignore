# frozen_string_literal: true

class PathList
  module Matchers
    class Mutable < Wrapper
      def self.build(wrapper = Blank)
        new(wrapper)
      end

      def initialize(matcher)
        @matcher = matcher

        # not frozen!
      end

      def matcher=(value)
        @matcher = value
        @weight = nil
      end

      def weight
        @weight ||= @matcher.weight + 1
      end

      alias_method :squashable_with?, :equal?

      def squash(_, _)
        self
      end

      alias_method :==, :equal?
      attr_reader :matcher

      private

      def new_with_matcher(matcher)
        @matcher = matcher
        @weight = nil

        self
      end
    end
  end
end
