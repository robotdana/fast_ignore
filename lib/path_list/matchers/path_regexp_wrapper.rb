# frozen_string_literal: true

class PathList
  module Matchers
    class PathRegexpWrapper < Wrapper
      def self.build(token_regexps, matcher)
        return Blank if matcher == Blank

        new(PathList::TokenRegexp::Build.build(token_regexps), matcher)
      end

      def initialize(rule, matcher)
        @rule = rule
        @matcher = matcher
        @weight = calculate_weight

        freeze
      end

      def match(candidate)
        @matcher.match(candidate) if @rule.match?(candidate.full_path_downcase)
      end

      def inspect
        "#{self.class}.new(\n  #{@rule.inspect},\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      attr_reader :weight

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @rule == other.rule
      end

      protected

      attr_reader :rule

      private

      def calculate_weight
        # chaos guesses
        (@rule.inspect.length / 4.0) + 2 + @matcher.weight
      end

      def new_with_matcher(matcher)
        return Blank if matcher == Blank

        self.class.new(@rule, matcher)
      end
    end
  end
end
