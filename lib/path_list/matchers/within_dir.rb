# frozen_string_literal: true

class PathList
  module Matchers
    class WithinDir < Wrapper
      def self.build(dir, matcher)
        return matcher if matcher == Null || dir == '/'

        new(dir, matcher)
      end

      def initialize(dir, matcher)
        @dir = dir

        super(matcher)
      end

      def squashable_with?(other)
        super && @dir == other.dir
      end

      def match(candidate)
        candidate.with_path_relative_to(@dir) do |relative_candidate|
          @matcher.match(relative_candidate)
        end
      end

      protected

      attr_reader :dir

      private

      def new_with_matcher(matcher)
        self.class.build(@dir, matcher)
      end
    end
  end
end
