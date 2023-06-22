# frozen_string_literal: true

class PathList
  module Matchers
    class WithinDir < Wrapper
      def self.build(re_builder, matcher)
        return Blank if matcher == Blank
        rule = re_builder.to_regexp
        return Blank unless rule

        new(rule, matcher, re_builder)
      end

      def initialize(rule, matcher, re_builder = nil)
        @rule = rule
        @re_builder = re_builder
        @matcher = matcher

        @weight = calculate_weight

        freeze
      end

      def squashable_with?(other)
        super &&
          @re_builder&.parts == other.re_builder&.parts
      end

      def inspect
        "#{self.class}.new(\n  #{@rule.inspect}\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      def match(candidate)
        @matcher.match(candidate) if @rule.match?(candidate.full_path)
      end

      if Invalid.is_a?(ComparableInstance)
        def eql?(other)
          super(other, except: [:@rule, :@re_builder]) &&
            @rule.inspect == other.instance_variable_get(:@rule).inspect
        end
        alias_method :==, :eql?
      end

      protected

      attr_reader :rule
      attr_reader :re_builder

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2 + @matcher.weight
      end

      def new_with_matcher(matcher)
        self.class.new(@rule, matcher, @re_builder)
      end
    end
  end
end
