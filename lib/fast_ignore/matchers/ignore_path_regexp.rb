# frozen_string_literal: true

class FastIgnore
  module Matchers
    class IgnorePathRegexp
      attr_reader :dir_only
      alias_method :dir_only?, :dir_only
      undef :dir_only

      def initialize(rule, squashable, dir_only)
        @rule = rule
        @dir_only = dir_only
        @squashable = squashable

        freeze
      end

      def squashable_with?(other)
        other == Unmatchable || (
          @squashable &&
            other.instance_of?(self.class) &&
            other.squashable? &&
            @dir_only == other.dir_only?
        )
      end

      def squash(list)
        list -= [Unmatchable]
        return self if list == [self]

        self.class.new(::Regexp.union(list.map { |l| l.rule }), @squashable, @dir_only) # rubocop:disable Style/SymbolProc it breaks with protected methods
      end

      def file_only?
        false
      end

      def weight
        1
      end

      def removable?
        false
      end

      # :nocov:
      def inspect
        "#<IgnorePathRegexp #{'dir_only ' if @dir_only}#{@rule.inspect}>"
      end
      # :nocov:

      def match?(candidate)
        :ignore if @rule.match?(candidate.path)
      end

      protected

      attr_reader :rule

      def squashable?
        @squashable
      end
    end
  end
end
