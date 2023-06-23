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

      def squashable_with?(_)
        false
      end

      def weight
        @weight ||= @matcher.weight + 1
      end
    end
  end
end
