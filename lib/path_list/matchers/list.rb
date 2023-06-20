# frozen_string_literal: true

class PathList
  module Matchers
    class List < Base
      include Autoloader

      def self.build(matchers) # rubocop:disable Metrics/MethodLength
        matchers = compress(matchers)

        case matchers.length
        when 0 then Blank
        when 1 then matchers.first
        when 2 then self::Two.new(matchers[0], matchers[1])
        else
          case calculate_polarity(matchers)
          when :allow then self::Allow.new(matchers)
          when :ignore then self::Ignore.new(matchers)
          when :mixed
            new(matchers)
          else raise 'Oop'
          end
        end
      end

      def self.calculate_polarity(matchers)
        first_matcher_polarity = matchers.first.polarity

        return :mixed unless matchers.all? { |m| m.polarity == first_matcher_polarity }

        first_matcher_polarity
      end

      def self.compress(matchers)
        matchers = matchers.flat_map { |m| m.is_a?(self) ? m.matchers : m }

        invalid = matchers.include?(Invalid)
        matchers -= [Invalid, Blank]
        return [Invalid] if matchers.empty? && invalid

        matchers
      end

      attr_reader :matchers
      attr_reader :polarity
      attr_reader :weight

      def initialize(matchers)
        @matchers = matchers
        @polarity = calculate_polarity
        @weight = calculate_weight

        freeze
      end

      def squashable_with?(_)
        false
      end

      def inspect
        "#{self.class}.new([\n#{@matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')}\n])"
      end

      private

      def calculate_weight
        @matchers.sum(&:weight)
      end

      def calculate_polarity
        self.class.calculate_polarity(@matchers)
      end
    end
  end
end
