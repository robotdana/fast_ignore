# frozen_string_literal: true

class PathList
  module Matchers
    class Any
      class Ignore < Any
        def match(candidate)
          return :ignore if @matchers.any? { |m| m.match(candidate) }
        end
      end
    end
  end
end
