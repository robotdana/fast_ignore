# frozen_string_literal: true

class FastIgnore
  module Matchers
    class MatchOrDefault < Wrapper
      def initialize(matcher, default)
        @default = default

        super(matcher)
      end

      def squashable_with?(_)
        # :nocov:
        # TODO: consistent api
        false
        # :nocov:
      end

      def append(pattern)
        appended = @matcher.append(pattern)
        return false unless appended
        return self if appended == @matcher

        self.class.new(appended, @default)
      end

      def match(candidate)
        @matcher.match(candidate) || @default
      end
    end
  end
end
