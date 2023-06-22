# frozen_string_literal: true

class PathList
  module Matchers
    class Any
      class Allow < Any
        def match(candidate)
          :allow if @matchers.any? { |m| m.match(candidate) }
        end
      end
    end
  end
end
