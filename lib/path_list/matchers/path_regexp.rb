# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexp < Base
      attr_reader :polarity
      attr_reader :weight
      attr_writer :parts

      def self.build(rule, allow, parts)
        raise unless parts

        m = new(rule, allow)
        m.parts = parts
        m.freeze
      end

      def initialize(rule, allow)
        @rule = rule
        @polarity = allow ? :allow : :ignore

        # chaos guesses
        @weight = (rule.inspect.length / 4.0) + 2
      end

      def squashable_with?(other)
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
        "#{self.class}.new(#{@rule.inspect}, #{@polarity == :allow})"
      end

      def match(candidate)
        @polarity if @rule.match?(candidate.path)
      end

      def eql?(other)
        super(other, except: [:@rule, :@parts]) &&
          @rule.inspect == other.instance_variable_get(:@rule).inspect
      end
      alias_method :==, :eql?

      protected

      attr_reader :rule
      attr_reader :parts
    end
  end
end
