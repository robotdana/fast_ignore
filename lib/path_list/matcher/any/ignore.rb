# frozen_string_literal: true

class PathList
  class Matcher
    class Any
      class Ignore < Any
        def match(candidate)
          :ignore if @matchers.any? { |m| m.match(candidate) }
        end
      end
    end
  end
end
