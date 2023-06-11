# frozen_string_literal: true

class PathList
  module Matchers
    AllowAnyParent = Base.new

    class << AllowAnyParent
      def dir_only?
        true
      end

      def implicit?
        true
      end

      def inspect
        '#<PathList::Matchers::AllowAnyParent>'
      end

      def match(candidate)
        :allow if candidate.directory?
      end

      alias_method :eql?, :equal?
      alias_method :==, :eql?
    end

    AllowAnyParent.freeze
  end
end