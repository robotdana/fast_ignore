# frozen_string_literal: true

class FastIgnore
  module Matchers
    class Appendable < Wrapper
      def initialize(label, patterns, matcher)
        @label = label
        @patterns = patterns

        super(matcher)
      end

      def removable?
        false
      end

      def match(candidate)
        @matcher.match(candidate)
      end

      def append(pattern)
        if pattern.label == @label
          if @patterns.include?(pattern)
            self
          else
            self.class.new(@label, [*@patterns, pattern], LastMatch.new([@matcher, *pattern.build_appended]))
          end
        else
          super
        end
      end
    end
  end
end
