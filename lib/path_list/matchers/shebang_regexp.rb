# frozen_string_literal: true

class PathList
  module Matchers
    class ShebangRegexp < Base
      attr_reader :polarity

      def initialize(rule, allow)
        @rule = rule
        @polarity = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity
      end

      def squash(list)
        self.class.new(
          ::Regexp.union(
            list.map { |l| l.rule } # rubocop:disable Style/SymbolProc it breaks with protected methods
          ),
          @polarity == :allow
        )
      end

      def inspect
        "#<#{self.class} #{@polarity.inspect} #{@rule.inspect}>"
      end

      def match(candidate)
        return if candidate.filename.include?('.')

        @polarity if candidate.first_line.match?(@rule)
      end

      def weight
        2
      end

      protected

      attr_reader :rule
    end
  end
end
