class PathList
  module Matchers
    class AllowInSortedArray < Base
      def initialize(array)
        @array = array.sort
        @weight = array.length / 100.0
      end

      attr_reader :weight

      def polarity
        :allow
      end

      def match(candidate)
        full_path = candidate.full_path.downcase

        return :allow if @array.bsearch { |element| full_path <=> element }
      end
    end
  end
end
