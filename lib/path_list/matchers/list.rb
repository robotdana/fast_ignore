# frozen_string_literal: true

class PathList
  module Matchers
    class List < Base
      def self.build(matchers)
        matchers = compress(matchers)

        case matchers.length
        when 0 then Null
        when 1 then matchers.first
        else new(matchers)
        end
      end

      def self.compress(matchers)
        matchers = matchers.flat_map { |m| m.is_a?(self) ? m.matchers : m }

        unmatchable = matchers.include?(Unmatchable)
        matchers -= [Unmatchable, Null]
        return [Unmatchable] if matchers.empty? && unmatchable

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
        super("@matchers=[\n#{
          @matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')
        }\n]")
      end

      private

      def calculate_weight
        @matchers.sum(&:weight)
      end

      def calculate_polarity
        first_matcher_polarity = @matchers.first.polarity

        return :mixed unless @matchers.all? { |m| m.polarity == first_matcher_polarity }

        first_matcher_polarity
      end
    end
  end
end
