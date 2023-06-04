# frozen_string_literal: true

class PathList
  module Matchers
    Unmatchable = Base.new

    class << Unmatchable
      def implicit?
        true
      end

      def inspect
        '#<PathList::Matchers::Unmatchable>'
      end

      def match(_)
        nil
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    Unmatchable.freeze
  end
end
