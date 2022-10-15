# frozen_string_literal: true

class FastIgnore
  module Matchers
    class WithinDir < Wrapper
      def initialize(matcher, dir)
        @dir = dir

        super(matcher)
      end

      def squashable_with?(other)
        super && @dir == other.dir
      end

      def match(candidate)
        candidate.with_path_relative_to(@dir) do
          @matcher.match(candidate)
        end
      end

      protected

      attr_reader :dir

      private

      def new_with_matcher(matcher)
        # :nocov:
        # TODO: consistent api
        self.class.new(matcher, @dir)
        # :nocov:
      end
    end
  end
end
