# frozen_string_literal: true

class PathList
  module Matchers
    class ExactString < Base
      include Autoloader

      def self.build(array, polarity)
        case array.length
        when 0 then Blank
        when 1 then new(array.first, polarity)
        # i'm not sure where the crossover is where bsearch's overhead becomes worth it
        # but it might be somewhere around here
        when 2...16 then self::Include.new(array, polarity)
        else
          self::Bsearch.new(array.sort, polarity)
        end
      end

      def initialize(item, polarity)
        @polarity = polarity
        @item = item

        freeze
      end

      def match(candidate)
        return @polarity if @item == candidate.full_path_downcase
      end

      def inspect
        "#{self.class}.new(#{@item.inspect}, #{@polarity.inspect})"
      end

      attr_reader :polarity

      def squashable_with?(other)
        other.is_a?(ExactString) && other.polarity == @polarity
      end

      def squash(list, _)
        self.class.build(list.flat_map { |l| l.array }.uniq, @polarity) # rubocop:disable Style/SymbolProc protected
      end

      def array
        [@item]
      end
    end
  end
end
