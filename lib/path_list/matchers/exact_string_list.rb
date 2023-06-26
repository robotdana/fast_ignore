# frozen_string_literal: true

class PathList
  module Matchers
    class ExactStringList < Base
      def self.build(array, polarity)
        new(array.sort, polarity)
      end

      def initialize(array, polarity)
        @polarity = polarity
        @array = array
        @weight = array.length / 100.0
      end

      def inspect
        "#{self.class}.new(\n[  #{@array.map(&:inspect).join(",\n  ")}],\n  #{@polarity}\n)"
      end

      def squashable_with?(other)
        other.instance_of?(self.class) &&
          other.polarity == @polarity
      end

      def squash(list)
        self.class.build(list.flat_map(&:array), @polarity)
      end

      attr_reader :weight
      attr_reader :polarity

      def match(candidate)
        full_path = candidate.full_path.downcase

        return @polarity if @array.bsearch { |element| full_path <=> element }
      end

      protected

      attr_reader :array
    end
  end
end
