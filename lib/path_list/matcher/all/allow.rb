# frozen_string_literal: true

class PathList
  class Matcher
    class All
      class Allow < All
        def match(candidate)
          :allow if @matchers.all? { |m| m.match(candidate) }
        end

        def polarity
          :allow
        end
      end
    end
  end
end
