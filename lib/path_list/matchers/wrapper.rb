# frozen_string_literal: true

class PathList
  module Matchers
    class Wrapper < Base
      def self.build(matcher)
        return Null if matcher == Null

        new(matcher)
      end

      def initialize(matcher)
        @matcher = matcher

        freeze
      end

      def polarity
        @matcher.polarity
      end

      def weight
        @matcher.weight
      end

      def squashable_with?(other)
        other.instance_of?(self.class)
      end

      def squash(list)
        new_with_matcher(
          Any.build(list.map { |l| l.matcher }) # rubocop:disable Style/SymbolProc it breaks with protected methods
        )
      end

      def inspect(extra = '')
        "#<#{self.class} #{extra}#{' ' if extra}@matcher=(\n#{@matcher.inspect.gsub(/^/, '  ')}\n)>"
      end

      protected

      attr_reader :matcher

      private

      def new_with_matcher(matcher)
        self.class.new(matcher)
      end
    end
  end
end
