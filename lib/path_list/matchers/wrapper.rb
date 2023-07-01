# frozen_string_literal: true

class PathList
  module Matchers
    class Wrapper < Base
      def self.build(matcher)
        return Blank if matcher == Blank

        new(matcher)
      end

      def initialize(matcher)
        @matcher = matcher
        @weight = calculate_weight

        freeze
      end

      def match(candidate)
        @matcher.match(candidate)
      end

      def inspect
        "#{self.class}.new(\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      attr_reader :weight

      def polarity
        @matcher.polarity
      end

      def squashable_with?(other)
        other.instance_of?(self.class)
      end

      def squash(list, preserve_order)
        new_matcher_class = preserve_order ? LastMatch : Any
        new_with_matcher(new_matcher_class.build(list.map { |l| l.matcher })) # rubocop:disable Style/SymbolProc protected
      end

      def without_matcher(matcher)
        return Blank if matcher == self

        new_matcher = @matcher.without_matcher(matcher)
        new_matcher == @matcher ? self : new_with_matcher(new_matcher)
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

      def ==(other)
        other.instance_of?(self.class) &&
          @matcher == other.matcher
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
