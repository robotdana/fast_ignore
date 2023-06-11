# frozen_string_literal: true

class PathList
  module Matchers
    class WithinDir < Wrapper
      def self.build(matcher, dir)
        return matcher if dir == '/'

        new(matcher, dir)
      end

      def initialize(matcher, dir)
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
        self.class.new(matcher, @dir)
      end
    end
  end
end
