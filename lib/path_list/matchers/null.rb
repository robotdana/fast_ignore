# frozen_string_literal: true

class PathList
  module Matchers
    Null = Base.new

    class << Null
      def implicit?
        true
      end

      def inspect
        '#<PathList::Matchers::Null>'
      end

      def match(_)
        nil
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    Null.freeze
  end
end
