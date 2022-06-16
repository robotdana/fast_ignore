# frozen_string_literal: true

class FastIgnore
  module Matchers
    class MatchOrDefault
      def initialize(matcher, default)
        @matcher = matcher
        @default = default

        freeze
      end

      def squashable_with?(other)
        other == Unmatchable
      end

      def squash(_)
        self
      end

      def dir_only?
        @matcher.dir_only?
      end

      def file_only?
        @matcher.file_only?
      end

      def weight
        @matcher.weight
      end

      def removable?
        @matcher.removable?
      end

      def match?(candidate)
        @matcher.match?(candidate) || @default
      end
    end
  end
end
