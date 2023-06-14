# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < Base
      def initialize(rule, squashable, allow)
        @rule = rule
        @squashable = squashable
        @return_value = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        @squashable &&
          other.instance_of?(self.class) &&
          other.squashable? &&
          @return_value == other.return_value
      end

      def squash(list)
        self.class.new(
          ::Regexp.union(list.map { |l| l.rule }), # rubocop:disable Style/SymbolProc it breaks with protected methods,
          @squashable,
          @return_value == :allow
        )
      end

      def weight
        1
      end

      def polarity
        @return_value
      end

      def inspect
        "#<#{self.class} #{@return_value.inspect} #{@rule.inspect}>"
      end

      def match(candidate)
        @return_value if @rule.match?(candidate.path)
      end

      protected

      attr_reader :rule
      attr_reader :return_value

      attr_reader :squashable
      alias_method :squashable?, :squashable
      undef :squashable
    end
  end
end
