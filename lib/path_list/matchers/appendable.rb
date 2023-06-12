# frozen_string_literal: true

class PathList
  module Matchers
    class Appendable < Wrapper
      def initialize(label, default_matcher, implicit_matcher, explicit_matcher)
        @label = label
        @default_matcher = default_matcher
        @implicit_matcher = implicit_matcher
        @explicit_matcher = explicit_matcher

        build_matcher
      end

      def removable?
        false
      end

      def squashable_with?(_)
        false
      end

      def match(candidate)
        @matcher.match(candidate)
      end

      def append(pattern)
        pattern.allow = append_with_allow
        new_implicit, new_explicit = pattern.build_matchers

        @implicit_matcher = Any.new([@implicit_matcher, new_implicit])
        @explicit_matcher = LastMatch.new([@explicit_matcher, new_explicit])

        build_matcher
      end

      private

      def append_with_allow
        @default_matcher == Matchers::Ignore
      end

      def build_matcher
        @matcher = if @implicit_matcher.removable? && @explicit_matcher.removable?
          Allow
        else
          LastMatch.build([@default_matcher, @implicit_matcher, @explicit_matcher])
        end
      end
    end
  end
end
