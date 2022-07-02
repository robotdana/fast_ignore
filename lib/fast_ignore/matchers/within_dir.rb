# frozen_string_literal: true

class FastIgnore
  module Matchers
    class WithinDir
      attr_reader :dir

      def initialize(matchers, dir)
        @matcher = MatchByType.new(matchers)
        @dir = dir

        freeze
      end

      def weight
        @matcher.weight
      end

      def removable?
        @matcher.removable?
      end

      def dir_only?
        @matcher.dir_only?
      end

      def file_only?
        @matcher.file_only?
      end

      def squashable_with?(other)
        other == Unmatchable || (
          other.instance_of?(WithinDir) && @dir == other.dir
        )
      end

      def squash(list)
        list -= [Unmatchable]
        return self if list == [self]

        self.class.new(list.map { |l| l.matcher }, @dir) # rubocop:disable Style/SymbolProc it breaks with protected methods
      end

      def match?(candidate)
        relative_candidate = candidate.relative_to(@dir)
        return false unless relative_candidate

        @matcher.match?(relative_candidate)
      end

      protected

      attr_reader :matcher
    end
  end
end
