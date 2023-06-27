# frozen_string_literal: true

class PathList
  module Matchers
    class MatchRegexp < Base
      attr_reader :polarity
      attr_reader :weight

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

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity &&
          @re_builder && other.re_builder
      end

      def squash(list)
        self.class.build(RegexpBuilder.union(list.map { |l| l.re_builder }), @polarity) # rubocop:disable Style/SymbolProc it breaks with protected methods,
      end

      def inspect
        "#{self.class}.new(#{@rule.inspect}, #{@polarity.inspect})"
      end

      def match(candidate)
        @polarity if @rule.match?(candidate.full_path_downcase)
      end

      protected

      attr_reader :re_builder

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2
      end
    end
  end
end
