# frozen_string_literal: true

class PathList
  module Matchers
    class MatchRegexp < Base
      def self.build(regexp_tokens, polarity)
        return Blank if regexp_tokens.all?(&:empty?)

        new(regexp_tokens, polarity)
      end

      def initialize(regexp_tokens, polarity)
        @polarity = polarity
        # @rule = here is just to make the tests nice
        @rule = @regexp_tokens = regexp_tokens
        @weight = calculate_weight
      end

      def prepare
        return self if frozen?

        @rule = TokenRegexp::Build.build(@regexp_tokens)

        freeze
      end

      def inspect
        "#{self.class}.new(#{@rule&.inspect || RegexpBuilder.build(@regexp_tokens).inspect}, #{@polarity.inspect})"
      end

      attr_reader :weight
      attr_reader :polarity

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity
      end

      def squash(list, _)
        s = self.class.build(list.flat_map { |l| l.regexp_tokens }, @polarity) # rubocop:disable Style/SymbolProc it breaks with protected methods,
        s.prepare if frozen?
        s
      end

      protected

      attr_reader :regexp_tokens
    end
  end
end
