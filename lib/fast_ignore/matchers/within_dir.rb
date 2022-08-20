# frozen_string_literal: true

class FastIgnore
  module Matchers
    class WithinDir < Wrapper
      attr_reader :dir

      def initialize(matcher, dir)
        @dir = dir
        super(matcher)
      end

      def squashable_with?(other)
        super && @dir == other.dir
      end

      def squash(list)
        # :nocov:
        # TODO: consistent api
        self.class.new(squash_matchers(list), @dir)
        # :nocov:
      end

      def match(candidate)
        candidate.with_path_relative_to(@dir) do
          @matcher.match(candidate)
        end
      end
    end
  end
end
