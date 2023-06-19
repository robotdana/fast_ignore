# frozen_string_literal: true

class PathList
  module Matchers
    class Wrapper < Base
      attr_reader :weight

      def self.build(matcher)
        return Blank if matcher == Blank

        new(matcher)
      end

      def initialize(matcher)
        @matcher = matcher
        @weight = calculate_weight

        freeze
      end

      def polarity
        @matcher.polarity
      end

      def squashable_with?(other)
        other.instance_of?(self.class)
      end

      def squash(list)
        new_with_matcher(
          LastMatch.build(list.map { |l| l.matcher }) # rubocop:disable Style/SymbolProc it breaks with protected methods
        )
      end

      def inspect(data = '')
        super("#{data}#{' ' if data}@matcher=(\n#{@matcher.inspect.gsub(/^/, '  ')}\n)")
      end

      protected

      attr_reader :matcher

      private

      def new_with_matcher(matcher)
        self.class.new(matcher)
      end

      def calculate_weight
        @matcher.weight
      end
    end
  end
end
