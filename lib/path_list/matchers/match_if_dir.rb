# frozen_string_literal: true

class PathList
  module Matchers
    class MatchIfDir < Wrapper
      def match(candidate)
        @matcher.match(candidate) if candidate.directory?
      end
    end
  end
end
