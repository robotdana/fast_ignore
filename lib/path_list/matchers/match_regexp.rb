# frozen_string_literal: true

class PathList
  module Matchers
    class MatchRegexp < Base
      attr_reader :polarity
      attr_reader :weight
      attr_writer :parts

      def self.build(rule, allow, parts)
        m = new(rule, allow)
        m.parts = parts
        m.freeze
      end

      def initialize(rule, allow)
        @rule = rule
        @polarity = allow ? :allow : :ignore

        @weight = calculate_weight
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity &&
          @parts && other.parts
      end

      def squash(list)
        RegexpBuilder.new(
          RegexpBuilder.merge_parts_lists(
            list.map { |l| l.parts } # rubocop:disable Style/SymbolProc it breaks with protected methods,
          )
        ).build_matcher(self.class, @polarity == :allow)
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

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2
      end
    end
  end
end
