# frozen_string_literal: true

class PathList
  module Matchers
    class Appendable < Wrapper
      def initialize(label, matcher)
        @label = label

        super(matcher)
      end

      def removable?
        false
      end

      def squashable_with?(other)
        super && @label == other.label
      end

      def match(candidate)
        @matcher.match(candidate)
      end

      def append(pattern)
        if pattern.label == @label
          new_matcher = LastMatch.new([@matcher.append(pattern) || @matcher, *pattern.build_appended])

          self.class.new(@label, new_matcher)
        else
          super
        end
      end

      protected

      attr_reader :label

      private

      def new_with_matcher(matcher)
        self.class.new(@label, matcher)
      end
    end
  end
end
