# frozen_string_literal: true

class PathList
  module Matchers
    class Base
      # build
      class << self
        alias_method :build, :new
      end

      # match
      def match(_)
        nil
      end

      # inspect
      alias_method :original_inspect, :inspect # leftovers:keep
      def inspect
        "#{self.class}.new"
      end

      # sort
      def weight
        1
      end

      # merge
      def polarity
        :mixed
      end

      # squash
      alias_method :squashable_with?, :equal?

      def squash(_, _)
        self
      end

      alias_method :dir_matcher, :itself
      alias_method :file_matcher, :itself
    end
  end
end
