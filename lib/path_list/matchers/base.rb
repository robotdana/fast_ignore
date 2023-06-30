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
      def squashable_with?(other)
        equal?(other)
      end

      def squash(_, _)
        self
      end

      # compress
      def compress_self
        self
      end

      # filter matchers
      def without_matcher(matcher)
        return Blank if matcher == self

        self
      end

      def dir_matcher
        self
      end

      def file_matcher
        self
      end
    end
  end
end
