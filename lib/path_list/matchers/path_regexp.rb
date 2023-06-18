# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < Base
      attr_reader :polarity
      attr_reader :weight

      def initialize(rule, squashable, allow, parts = nil)
        @rule = rule
        @squashable = squashable
        # chaos
        @weight = (rule.inspect.length / 4.0) + 2

        @polarity = allow ? :allow : :ignore

        @parts = parts

        freeze
      end

      def squashable_with?(other)
        @squashable &&
          other.instance_of?(self.class) &&
          @polarity == other.polarity &&
          @parts && other.parts
      end

      def squash(list)
        Rule.new(
          Rule.merge_parts_lists(
            list.map { |l| l.parts } # rubocop:disable Style/SymbolProc it breaks with protected methods,
          ),
          @polarity == :allow
        ).build
      end

      def inspect
        super("#{@polarity.inspect} #{@rule.inspect}")
      end

      def match(candidate)
        @polarity if @rule.match?(candidate.path)
      end

      def eql?(other)
        super(other, except: [:@rule, :@parts, :@squashable]) &&
          @rule.inspect == other.instance_variable_get(:@rule).inspect
      end
      alias_method :==, :eql?

      protected

      attr_reader :rule
      attr_reader :parts

      attr_reader :squashable
      alias_method :squashable?, :squashable
      undef :squashable
    end
  end
end
