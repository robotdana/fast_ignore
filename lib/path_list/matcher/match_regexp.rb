# frozen_string_literal: true

class PathList
  class Matcher
    class MatchRegexp < Matcher
      def self.build(regexp_tokens, polarity)
        return Blank if regexp_tokens.all?(&:empty?)

        new(TokenRegexp::Build.build(regexp_tokens), polarity, regexp_tokens)
      end

      def initialize(rule, polarity, regexp_tokens = nil)
        @polarity = polarity
        @regexp_tokens = regexp_tokens
        @rule = rule
        @weight = calculate_weight

        freeze
      end

      def inspect
        "#{self.class}.new(#{@rule.inspect}, #{@polarity.inspect})"
      end

      attr_reader :weight
      attr_reader :polarity

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity
      end

      def squash(list, _)
        self.class.build(list.flat_map { |l| l.regexp_tokens }, @polarity) # rubocop:disable Style/SymbolProc it breaks with protected methods,
      end

      def ==(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity &&
          @rule == other.rule
      end

      protected

      attr_reader :regexp_tokens
      attr_reader :rule
    end
  end
end
