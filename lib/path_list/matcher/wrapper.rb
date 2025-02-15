# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    # @abstract
    class Wrapper < Matcher
      # @param matcher [PathList::Matcher] to wrap
      # @return [PathList::Matcher]
      def self.build(matcher)
        return Blank if matcher == Blank

        new(matcher)
      end

      # @param matcher [PathList::Matcher] to wrap
      def initialize(matcher)
        @matcher = matcher
        @weight = calculate_weight

        freeze
      end

      # Does the candidate match this matcher
      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        @matcher.match(candidate)
      end

      # @return (see Matcher#inspect)
      def inspect
        "#{self.class}.new(\n#{@matcher.inspect.gsub(/^/, '  ')}\n)"
      end

      # @return (see Matcher#weight)
      attr_reader :weight

      # @return (see Matcher#polarity)
      def polarity
        @matcher.polarity
      end

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      def squashable_with?(other)
        other.instance_of?(self.class)
      end

      # @param (see Matcher#squash)
      # @return (see Matcher#squash)
      def squash(list, preserve_order)
        new_matcher_class = preserve_order ? LastMatch : Any
        # protected method, so we can't use SymbolProc
        new_with_matcher(new_matcher_class.build(list.map { |l| l.matcher })) # rubocop:disable Style/SymbolProc
      end

      # @return (see Matcher#dir_matcher)
      def dir_matcher
        new_matcher = @matcher.dir_matcher
        return self unless new_matcher != @matcher

        new_with_matcher(new_matcher)
      end

      # @return (see Matcher#file_matcher)
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
