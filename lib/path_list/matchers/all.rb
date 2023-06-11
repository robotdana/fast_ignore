# frozen_string_literal: true

class PathList
  module Matchers
    class All < List
      def initialize(matchers)
        @matchers = matchers.sort_by(&:weight)
      end

      def match(candidate)
        if @matchers.all? { |m| m.match(candidate) == :allow }
          :allow
        else
          :ignore
        end
      end
    end
  end
end
