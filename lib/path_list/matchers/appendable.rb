# frozen_string_literal: true

class PathList
  module Matchers
    class Appendable < Wrapper
      attr_reader :default
      attr_reader :label
      attr_reader :implicit
      attr_reader :explicit

      def initialize(label, default, implicit, explicit)
        @label = label
        @default = default
        @implicit = implicit
        @explicit = explicit

        @matcher = if implicit.removable? && explicit.removable?
          Allow
        else
          LastMatch.build([default, implicit, explicit])
        end

        freeze
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

      def append(patterns)
        if patterns.label == @label
          patterns_implicit, patterns_explicit = patterns.build_matchers

          self.class.new(
            @label,
            @default,
            Any.build([@implicit, patterns_implicit]),
            LastMatch.build([@explicit, patterns_explicit])
          )
        else
          appended_implicit = @implicit.append(patterns)
          appended_explicit = @explicit.append(patterns)

          return unless appended_implicit || appended_explicit

          self.class.new(
            @label,
            @default,
            appended_implicit || @implicit,
            appended_explicit || @explicit
          )
        end
      end

      protected

      attr_reader :default
      attr_reader :label
      attr_reader :implicit
      attr_reader :explicit
    end
  end
end
