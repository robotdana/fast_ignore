# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < Base
      attr_reader :polarity
      attr_reader :weight

      def initialize(rule, squashable, allow)
        @rule = rule
        @squashable = squashable
        # chaos
        @weight = squashable ? 2 : (rule.inspect.length / 4.0) + 2

        @polarity = allow ? :allow : :ignore

        freeze
      end

      def squashable_with?(other)
        @squashable &&
          other.instance_of?(self.class) &&
          other.squashable? &&
          @polarity == other.polarity
      end

      def squash(list)
        self.class.new(
          ::Regexp.union(list.map { |l| l.rule }), # rubocop:disable Style/SymbolProc it breaks with protected methods,
          @squashable,
          @polarity == :allow
        )
      end

      def inspect
        super("#{@polarity.inspect} #{@rule.inspect}")
      end

      def match(candidate)
        @polarity if @rule.match?(candidate.path)
      end

      def eql?(other)
        super(other, except: :@rule) &&
          @rule.inspect == other.instance_variable_get(:@rule).inspect
      end
      alias_method :==, :eql?

      protected

      attr_reader :rule

      attr_reader :squashable
      alias_method :squashable?, :squashable
      undef :squashable
    end
  end
end
