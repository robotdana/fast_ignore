# frozen_string_literal: true

class PathList
  module Matchers
    class MatchIfDir < Wrapper
      def match(candidate)
        @matcher.match(candidate) if candidate.directory?
      end

      def inspect
        matcher == Allow ? '#<PathList::Matchers::AllowAnyDir>' : super
      end

      private

      def calculate_weight
        # arbitrary, files to directories ratio from my projects dir
        (super * 0.2) + 1
      end
    end
  end
end
