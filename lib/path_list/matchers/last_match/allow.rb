# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch
      class Allow < LastMatch
        def match(candidate)
          :allow if @matchers.reverse_each.any? { |matcher| matcher.match(candidate) }
        end
      end
    end
  end
end
