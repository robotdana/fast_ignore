# frozen_string_literal: true

class PathList
  module Matchers
    class MatchIfDir < Wrapper
      def match(candidate)
        @matcher.match(candidate) if candidate.directory?
      end

      def weight
        # arbitrary, files to directories ratio
        (@matcher.weight / 5.0) + 1
      end
    end
  end
end
