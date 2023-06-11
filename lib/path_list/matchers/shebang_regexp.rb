# frozen_string_literal: true

class PathList
  module Matchers
    class ShebangRegexp < Base
      def initialize(rule, allow)
        @rule = rule
        @return_value = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        other.instance_of?(ShebangRegexp) &&
          @return_value == other.return_value
      end

      def polarity
        @return_value
      end

      def squash(list)
        self.class.new(
          ::Regexp.union(
            list.map { |l| l.rule } # rubocop:disable Style/SymbolProc it breaks with protected methods
          ),
          @return_value == :allow
        )
      end

      def inspect
        "#<#{self.class} #{@return_value.inspect} #{@rule.inspect}>"
      end

      def match(candidate)
        return if candidate.filename.include?('.')

        @return_value if candidate.first_line.match?(@rule)
      end

      def weight
        2
      end

      protected

      attr_reader :return_value
      attr_reader :rule
    end
  end
end
