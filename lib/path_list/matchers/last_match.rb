# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      def match(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        nil
      end
    end
  end
end
