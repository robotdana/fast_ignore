# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexpWrapper < Wrapper
      def self.build(re_builder, matcher)
        rule = re_builder.to_regexp
        return matcher unless rule
        return Blank if matcher == Blank

        new(rule, matcher, re_builder)
      end

      def compress_self
        return self.class.build(@re_builder.compress, matcher.compress_self) unless @re_builder.compressed?

        super
      end

      def initialize(rule, matcher, re_builder = nil)
        @rule = rule
        @matcher = matcher
        @re_builder = re_builder
        @weight = calculate_weight

        freeze
      end

      def match(candidate)
        @matcher.match(candidate) if @rule.match?(candidate.full_path_downcase)
      end

      def inspect
        "#{self.class}.new(\n  #{@rule.inspect},\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      attr_reader :weight

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @re_builder.parts == other.re_builder.parts
      end

      protected

      attr_reader :re_builder

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2 + @matcher.weight
      end

      def new_with_matcher(matcher)
        return Blank if matcher == Blank

        self.class.new(@rule, matcher, @re_builder)
      end
    end
  end
end
