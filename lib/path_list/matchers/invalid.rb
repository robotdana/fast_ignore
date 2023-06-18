# frozen_string_literal: true

class PathList
  module Matchers
    Invalid = Base.new

    class << Invalid
      def name
        'PathList::Matchers::Invalid'
      end

      def match(_)
        nil
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    Invalid.freeze
  end
end
