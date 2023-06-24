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

      def compress_self
        new_matcher = @matcher.compress_self
        new_matcher == @matcher ? self : new_with_matcher(new_matcher)
      end

      def inspect
        "#{self.class}.new(\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      def match(candidate)
        @matcher.match(candidate)
      end

      def dir_matcher
        new_matcher = @matcher.dir_matcher
        return self unless new_matcher != @matcher

        new_with_matcher(new_matcher)
      end

      def file_matcher
        new_matcher = @matcher.file_matcher
        return self unless new_matcher != @matcher

        new_with_matcher(new_matcher)
      end

      protected

      attr_accessor :matcher

      private

      def calculate_weight
        @matcher.weight
      end

      def new_with_matcher(matcher)
        self.class.build(matcher)
      end
    end
  end
end
