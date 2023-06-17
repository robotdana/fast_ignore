# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < Base
      attr_reader :polarity

      def initialize(rule, squashable, allow)
        @rule = rule
        @squashable = squashable
        @polarity = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        @squashable &&
          other.instance_of?(self.class) &&
          other.squashable? &&
          @polarity == other.polarity
      end

      def squash(list)
        self.class.new(
          ::Regexp.union(list.map { |l| l.rule }), # rubocop:disable Style/SymbolProc it breaks with protected methods,
          @squashable,
          @polarity == :allow
        )
      end

      def weight
        1
      end

      def inspect
        "#<#{self.class} #{@polarity.inspect} #{@rule.inspect}>"
      end

      def match(candidate)
        @polarity if @rule.match?(candidate.path)
      end

      protected

      attr_reader :rule

      attr_reader :squashable
      alias_method :squashable?, :squashable
      undef :squashable
    end
  end
end
