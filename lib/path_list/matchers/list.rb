# frozen_string_literal: true

class PathList
  module Matchers
    class List < Base
      def self.build(matchers)
        matchers = compress(matchers)

        case matchers.length
        when 0 then new([])
        when 1 then matchers.first
        else new(matchers)
        end
      end

      def self.compress(matchers)
        matchers = matchers.flat_map { |m| m.is_a?(self) ? m.matchers : m }

        unmatchable = matchers.include?(Unmatchable)
        matchers -= [Unmatchable]
        matchers.compact!
        matchers.reject!(&:removable?)
        return [Unmatchable] if matchers.empty? && unmatchable

        matchers
      end

      attr_reader :matchers

      def initialize(matchers)
        @matchers = matchers

        freeze
      end

      def polarity
        return :mixed if matchers.empty? # TODO: temporary

        matchers.all? { |m| m.polarity == matchers.first.polarity } ? matchers.first.polarity : :mixed
      end

      def squashable_with?(_)
        false
      end

      def weight
        @matchers.sum(&:weight)
      end

      def removable?
        @matchers.empty? || @matchers.all?(&:removable?)
      end

      def implicit?
        @matchers.all?(&:implicit?)
      end

      def append(pattern)
        did_append = false

        new_matchers = @matchers.map do |matcher|
          appended_matcher = matcher.append(pattern)
          did_append ||= appended_matcher

          appended_matcher || matcher
        end

        return unless did_append

        self.class.new(new_matchers)
      end
    end
  end
end
