# frozen_string_literal: true

class PathList
  module Matchers
    class Dir < Wrapper
      def match(candidate)
        candidate.directory?
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
