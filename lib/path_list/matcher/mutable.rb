# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    class Mutable < Wrapper
      # @param (see Wrapper.build)
      # @return (see Wrapper.build)
      def self.build(wrapper = Blank)
        new(wrapper)
      end

      # @param (see Wrapper.build)
      def initialize(matcher)
        @matcher = matcher

        # not frozen!
      end

      # @param value [PathList::Matcher]
      def matcher=(value)
        @matcher = value
        @weight = nil
      end

      # @return (see Matcher#weight)
      def weight
        @weight ||= @matcher.weight + 1
      end

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      alias_method :squashable_with?, :equal?

      # @param (see Matcher#squash)
      # @return (see Matcher#squash)
      def squash(_list, _preserve_order)
        self
      end

      # @return [PathList:Matcher]
      attr_reader :matcher

      # @return (see Matcher#polarity)
      def polarity
        :mixed
      end

      private

      def new_with_matcher(matcher)
        @matcher = matcher
        @weight = nil

        self
      end
    end
  end
end
