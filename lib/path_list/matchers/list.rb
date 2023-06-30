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
          else
            new(matchers)
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
        matchers -= [Blank]

        matchers
      end

      def initialize(matchers)
        @matchers = matchers
        @polarity = calculate_polarity
        @weight = calculate_weight

        freeze
      end

      def inspect
        "#{self.class}.new([\n#{matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')}\n])"
      end

      attr_reader :weight
      attr_reader :polarity

      def compress_self
        new_matchers = matchers.map(&:compress_self)
        new_matchers == matchers ? self : self.class.build(new_matchers)
      end

      def without_matcher(matcher)
        return Blank if matcher == self

        new_matchers = matchers.map { |m| m.without_matcher(matcher) }
        new_matchers == matchers ? self : self.class.build(new_matchers)
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

      attr_reader :matchers

      private

      def calculate_weight
        matchers.sum(&:weight)
      end

      def calculate_polarity
        self.class.calculate_polarity(matchers)
      end
    end
  end
end
