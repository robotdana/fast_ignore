# frozen_string_literal: true

class PathList
  class Matcher
    # @api private
    # @abstract
    class List < Matcher
      Autoloader.autoload(self)

      # @param matchers [Array<PathList::Matcher>]
      # @return (see Matcher.build)
      def self.build(matchers)
        matchers = compress(matchers)

        case matchers.length
        when 0 then Blank
        when 1 then matchers.first
        when 2 then self::Two.new(matchers)
        else
          case calculate_polarity(matchers)
          when :allow then self::Allow.new(matchers)
          when :ignore then self::Ignore.new(matchers)
          else
            new(matchers)
          end
        end
      end

      # @param matchers [Array<PathList::Matcher>]
      # @return (see Matcher#polarity)
      def self.calculate_polarity(matchers)
        first_matcher_polarity = matchers.first.polarity

        return :mixed unless matchers.all? { |m| m.polarity == first_matcher_polarity }

        first_matcher_polarity
      end

      # @param matchers [Array<PathList::Matcher>]
      # @return [Array<PathList::Matcher>]
      def self.compress(matchers)
        matchers = matchers.flat_map { |m| m.is_a?(self) ? m.matchers : m }
        matchers.delete(Blank)

        matchers
      end

      # @param matchers [Array<PathList::Matcher>]
      def initialize(matchers)
        @matchers = matchers
        @polarity = calculate_polarity
        @weight = calculate_weight

        freeze
      end

      # @return (see Matcher#inspect)
      def inspect
        "#{self.class}.new([\n#{@matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')}\n])"
      end

      # @return (see Matcher#weight)
      attr_reader :weight
      # @return (see Matcher#weight)
      attr_reader :polarity

      # @return (see Matcher#dir_matcher)
      def dir_matcher
        new_matchers = @matchers.map(&:dir_matcher)
        return self unless new_matchers != @matchers

        self.class.build(new_matchers)
      end

      # @return (see Matcher#file_matcher)
      def file_matcher
        new_matchers = @matchers.map(&:file_matcher)
        return self unless new_matchers != @matchers

        self.class.build(new_matchers)
      end

      # @return [Array<Matcher>]
      attr_reader :matchers

      private

      def calculate_weight
        @matchers.sum(&:weight)
      end

      def calculate_polarity
        self.class.calculate_polarity(matchers)
      end
    end
  end
end
