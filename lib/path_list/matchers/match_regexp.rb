# frozen_string_literal: true

class PathList
  module Matchers
    class MatchRegexp < Base
      attr_reader :polarity
      attr_reader :weight

      def self.build(re_builder, allow)
        rule = re_builder.to_regexp
        return allow ? Allow : Ignore unless rule

        new(rule, allow, re_builder)
      end

      def initialize(rule, allow, re_builder = nil)
        @rule = rule
        @polarity = allow ? :allow : :ignore
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
        self.class.build(RegexpBuilder.union(list.map { |l| l.re_builder }), @polarity == :allow) # rubocop:disable Style/SymbolProc it breaks with protected methods,
      end

      def inspect
        "#{self.class}.new(#{@rule.inspect}, #{@polarity == :allow})"
      end

      def match(candidate)
        @polarity if @rule.match?(candidate.path)
      end

      def eql?(other)
        super(other, except: [:@rule, :@re_builder]) &&
          @rule.inspect == other.instance_variable_get(:@rule).inspect
      end
      alias_method :==, :eql?

      protected

      attr_reader :rule
      attr_reader :re_builder

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2
      end
    end
  end
end
