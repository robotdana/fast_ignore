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
        new_matchers = list.map { |l| l.matcher } # rubocop:disable Style/SymbolProc it breaks with protected methods
        first_polarity = new_matchers.first.polarity
        same_polarity = new_matchers.all? { |l| l.polarity != :mixed && l.polarity == first_polarity }
        new_matcher_class = same_polarity ? Any : LastMatch
        new_with_matcher(new_matcher_class.build(new_matchers))
      end

      def inspect
        "#{self.class}.new(\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      def match(candidate)
        @matcher.match(candidate)
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
