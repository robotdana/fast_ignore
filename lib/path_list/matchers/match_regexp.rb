# frozen_string_literal: true

class PathList
  module Matchers
    class MatchRegexp < Base
      def self.build(re_builder, polarity)
        rule = re_builder.to_regexp
        return polarity == :allow ? Allow : Ignore unless rule

        new(rule, polarity, re_builder)
      end

      def initialize(rule, polarity, re_builder = nil)
        @rule = rule
        @polarity = polarity
        @re_builder = re_builder
        @weight = calculate_weight

        freeze
      end

      def inspect
        "#{self.class}.new(#{@rule.inspect}, #{@polarity.inspect})"
      end

      attr_reader :weight
      attr_reader :polarity

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity
      end

      def squash(list, _)
        self.class.build(RegexpBuilder.union(list.map { |l| l.re_builder }), @polarity) # rubocop:disable Style/SymbolProc it breaks with protected methods,
      end

      protected

      attr_reader :re_builder
    end
  end
end
