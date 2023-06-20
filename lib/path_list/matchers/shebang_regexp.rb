# frozen_string_literal: true

class PathList
  module Matchers
    class ShebangRegexp < Base
      attr_reader :polarity
      attr_reader :weight

      def initialize(rule, allow)
        @rule = rule
        @polarity = allow ? :allow : :ignore
        @weight = (rule.inspect.length / 3.0) + 2
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
        "#{self.class}.new(#{@rule.inspect}, #{@polarity == :allow})"
      end

      def match(candidate)
        return if candidate.filename.include?('.')

        @polarity if candidate.first_line.match?(@rule)
      end

      protected

      attr_reader :rule
    end
  end
end
