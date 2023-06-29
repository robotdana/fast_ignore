# frozen_string_literal: true

class PathList
  module Matchers
    class All
      class Ignore < All
        def match(candidate)
          :ignore if @matchers.any? { |m| m.match(candidate) }
        end

        def polarity
          :ignore
        end
      end
    end
  end
end
