# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    # @abstract
    class MatchRegexp < Matcher
      # @param regexp_tokens [Array<Symbol, String, TokenRegexp::EscapedString>]
      # @param polarity [:allow, :ignore]
      # @return (see Matcher.build)
      def self.build(regexp_tokens, polarity)
        new(build_regexp(regexp_tokens), polarity, regexp_tokens)
      end

      # @param regexp_tokens [Array<Symbol, String, TokenRegexp::EscapedString>]
      # @return [Regexp]
      def self.build_regexp(regexp_tokens)
        TokenRegexp::Build.build(regexp_tokens)
      end

      # @param Regexp
      # @param regexp_tokens [Array<Symbol, String, TokenRegexp::EscapedString>]
      # @param polarity [:allow, :ignore]
      def initialize(regexp, polarity, regexp_tokens = nil)
        @polarity = polarity
        @regexp_tokens = regexp_tokens
        @regexp = regexp
        @weight = calculate_weight

        freeze
      end

      # @return (see Matcher#inspect)
      def inspect
        "#{self.class}.new(#{@regexp.inspect}, #{@polarity.inspect})"
      end

      # @return (see Matcher#weight)
      attr_reader :weight

      # @return (see Matcher#polarity)
      attr_reader :polarity

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity
      end

      # @param (see Matcher#squash)
      # @return (see Matcher#squash)
      def squash(list, _preserve_order)
        # protected method, so we can't use SymbolProc
        self.class.build(list.flat_map { |l| l.regexp_tokens }, @polarity) # rubocop:disable Style/SymbolProc
      end

      protected

      attr_reader :regexp_tokens
      attr_reader :regexp
    end
  end
end
