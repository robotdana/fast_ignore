# frozen_string_literal: true

class PathList
  module Matchers
    class ExactStringList < Base
      include Autoloader

      def self.build(array, polarity)
        case array.length
        when 0 then Blank
        when 1 then self::One.new(array, polarity)
        when 2..8 then self::Some.new(array, polarity)
        else
          new(array.sort, polarity)
        end
      end

      def initialize(array, polarity)
        @polarity = polarity
        @array = array
        @weight = (array.length / 20.0) + 1
      end

      def inspect
        "#{self.class}.new([\n  #{@array.map(&:inspect).join(",\n  ")}\n], #{@polarity.inspect})"
      end

      def squashable_with?(other)
        other.is_a?(ExactStringList) &&
          other.polarity == @polarity
      end

      def squash(list)
        self.class.build(list.flat_map { |l| l.array }, @polarity) # rubocop:disable Style/SymbolProc protected
      end

      attr_reader :weight
      attr_reader :polarity
      attr_reader :array

      def match(candidate)
        full_path = candidate.full_path_downcase

        return @polarity if @array.bsearch { |element| full_path <=> element }
      end
    end
  end
end
