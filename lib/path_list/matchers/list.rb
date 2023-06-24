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
        when 2 then self::Two.new(matchers)
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

      def compress_self
        new_matchers = matchers.map(&:compress_self)
        new_matchers == matchers ? self : self.class.new(new_matchers)
      end

      def inspect
        "#{self.class}.new([\n#{@matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')}\n])"
      end

      def dir_matcher
        new_matchers = matchers.map(&:dir_matcher)
        return self unless new_matchers != matchers

        self.class.build(new_matchers)
      end

      def file_matcher
        new_matchers = matchers.map(&:file_matcher)
        return self unless new_matchers != matchers

        self.class.build(new_matchers)
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
