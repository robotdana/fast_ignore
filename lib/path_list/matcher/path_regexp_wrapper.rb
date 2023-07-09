# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class PathRegexpWrapper < Wrapper
      # @param regexp [Regexp]
      # @param (see Wrapper.build)
      # @return (see Wrapper.build)
      def self.build(regexp, matcher)
        return Blank if matcher == Blank

        new(regexp, matcher)
      end

      # @param regexp [Regexp]
      # @param (see Wrapper.build)
      # @return (see Wrapper.build)
      def initialize(regexp, matcher)
        @regexp = regexp

        super(matcher)
      end

      # @param regexp [Regexp]
      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @matcher.match(candidate) if @regexp.match?(candidate.full_path)
      end

      # @return (see Matcher#inspect)
      def inspect
        "#{self.class}.new(\n  #{@regexp.inspect},\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      # @return (see Matcher#weight)
      attr_reader :weight

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      def squashable_with?(other)
        other.instance_of?(self.class) &&
          @regexp == other.regexp
      end

      protected

      attr_reader :regexp

      private

      def calculate_weight
        # chaos guesses
        (@regexp.inspect.length / 4.0) + 2 + @matcher.weight
      end

      def new_with_matcher(matcher)
        return Blank if matcher == Blank

        self.class.new(@regexp, matcher)
      end
    end
  end
end
