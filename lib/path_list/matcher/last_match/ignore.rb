# frozen_string_literal: true

class PathList
  class Matcher
    class LastMatch
      class Ignore < LastMatch
        def match(candidate)
          :ignore if @matchers.reverse_each.any? { |matcher| matcher.match(candidate) }
        end
      end
    end
  end
end
