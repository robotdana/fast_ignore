# frozen_string_literal: true

class PathList
  module Matchers
    class ExactString < ExactStringList
      def self.build(array, polarity)
        ExactStringList.build(array, polarity)
      end

      def initialize(item, polarity)
        @polarity = polarity
        @item = item
        @weight = 1
      end

      def match(candidate)
        return @polarity if @item == candidate.full_path_downcase
      end

      def inspect
        "#{self.class}.new(#{@item.inspect}, #{@polarity.inspect})"
      end

      def array
        [@item]
      end
    end
  end
end
