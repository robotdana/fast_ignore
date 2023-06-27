# frozen_string_literal: true

class PathList
  module Matchers
    class ExactStringList < Base
      include Autoloader

      def self.build(array, polarity)
        case array.length
        when 0 then Blank
        when 1 then ExactString.new(array.first, polarity)
        # i'm not sure where the crossover is where bsearch's overhead becomes worth it
        # but it might be somewhere around here
        when 2...16 then new(array, polarity)
        else
          ExactStringBsearch.new(array.sort, polarity)
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
        return @polarity if @array.include?(candidate.full_path_downcase)
      end
    end
  end
end
