# frozen_string_literal: true

class PathList
  module Matchers
    Blank = Base.new

    class << Blank
      def inspect
        'PathList::Matchers::Blank'
      end

      def match(_)
        nil
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    Blank.freeze
  end
end
