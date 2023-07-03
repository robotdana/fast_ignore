# frozen_string_literal: true

require 'set'

class PathList
  class Matcher
    class ExactString < Matcher
      Autoloader.autoload(self)

      def self.build(set, polarity)
        case set.length
        when 0 then Blank
        when 1 then new(set.first, polarity)
        else
          self::Set.new(set, polarity)
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
        self.class.build(list.each_with_object(::Set.new) { |l, s| s.merge(l.set) }, @polarity) # protected
      end

      def set
        ::Set[@item]
      end

      def ==(other)
        other.instance_of?(self.class) &&
          @polarity == other.polarity &&
          @item == other.item
      end

      protected

      attr_reader :item
    end
  end
end
