# frozen_string_literal: true

class PathList
  module Matchers
    Ignore = Base.new

    class << Ignore
      def polarity
        :ignore
      end

      def inspect
        '#<PathList::Matchers::Ignore>'
      end

      def match(_)
        :ignore
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    Ignore.freeze
  end
end
