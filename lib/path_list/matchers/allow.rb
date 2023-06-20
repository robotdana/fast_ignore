# frozen_string_literal: true

class PathList
  module Matchers
    Allow = Base.new

    class << Allow
      def polarity
        :allow
      end

      def inspect
        'PathList::Matchers::Allow'
      end

      def match(_)
        :allow
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    Allow.freeze
  end
end
