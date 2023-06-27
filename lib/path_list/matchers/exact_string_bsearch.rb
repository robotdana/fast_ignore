# frozen_string_literal: true

class PathList
  module Matchers
    class ExactStringBsearch < ExactStringList
      def self.build(array, polarity)
        ExactStringList.build(array, polarity)
      end

      def initialize(array, polarity)
        @polarity = polarity
        @array = array
        @weight = 1
      end

      def match(candidate)
        full_path = candidate.full_path_downcase

        return @polarity if @array.bsearch { |element| full_path <=> element }
      end
    end
  end
end
