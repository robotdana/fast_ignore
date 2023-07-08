# frozen_string_literal: true

require 'set'

class PathList
  class Matcher
    # @api private
    class ExactString < Matcher
      Autoloader.autoload(self)

      # @param set [Set]
      # @param polarity [:ignore, :allow]
      # @return (see Matcher.build)
      def self.build(set, polarity)
        case set.length
        when 0 then Blank
        when 1 then new(set.first, polarity)
        else
          self::Set.new(set, polarity)
        end
      end

      # @param item [String]
      # @param polarity [:ignore, :allow]
      def initialize(item, polarity)
        @polarity = polarity
        @item = item

        freeze
      end

      # @param (see Matcher#match)
      # @return (see Matcher#match)
      def match(candidate)
        return @polarity if @item == candidate.full_path_downcase
      end

      # @return (see Matcher#inspect)
      def inspect
        "#{self.class}.new(#{@item.inspect}, #{@polarity.inspect})"
      end

      # @return (see Matcher#polarity)
      attr_reader :polarity

      # @param (see Matcher#squashable_with?)
      # @return (see Matcher#squashable_with?)
      def squashable_with?(other)
        other.is_a?(ExactString) && other.polarity == @polarity
      end

      # @param (see Matcher#squash)
      # @return (see Matcher#squash)
      def squash(list, _)
        self.class.build(list.each_with_object(::Set.new) { |l, s| s.merge(l.set) }, @polarity) # protected
      end

      # @return set [Set]
      def set
        ::Set[@item]
      end

      protected

      attr_reader :item
    end
  end
end
