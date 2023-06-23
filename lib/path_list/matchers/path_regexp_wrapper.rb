# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexpWrapper < Wrapper
      attr_reader :polarity
      attr_reader :weight

      def self.build(re_builder, matcher)
        rule = re_builder.to_regexp
        return matcher unless rule

        new(rule, matcher, re_builder)
      end

      def initialize(rule, matcher, re_builder = nil)
        @rule = rule
        @matcher = matcher
        @re_builder = re_builder
        @weight = calculate_weight

        freeze
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @re_builder.parts == other.re_builder.parts
      end

      def inspect
        "#{self.class}.new(\n  #{@rule.inspect},\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      def match(candidate)
        @matcher.match(candidate) if @rule.match?(candidate.full_path)
      end

      protected

      attr_reader :rule
      attr_reader :re_builder

      private

      def new_with_matcher(matcher)
        self.class.new(@rule, matcher, @re_builder)
      end

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2 + @matcher.weight
      end
    end
  end
end
