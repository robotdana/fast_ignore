# frozen_string_literal: true

class PathList
  module Matchers
    class MatchUnlessDir < Wrapper
      def match(candidate)
        @matcher.match(candidate) unless candidate.directory?
      end
    end
  end
end
