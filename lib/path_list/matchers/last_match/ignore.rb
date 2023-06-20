# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch
      class Ignore < LastMatch
        def match(candidate)
          return :ignore if @matchers.reverse_each.any? { |matcher| matcher.match(candidate) }
        end
      end
    end
  end
end
