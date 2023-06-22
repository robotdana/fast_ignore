# frozen_string_literal: true

class PathList
  module Matchers
    class All
      class Allow < All
        def match(candidate)
          :allow if @matchers.all? { |m| m.match(candidate) }
        end
      end
    end
  end
end
