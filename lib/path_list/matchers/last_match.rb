# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      def initialize(matchers)
        @matchers = squash_matchers(matchers)

        freeze
      end

      def match(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        nil
      end

      private

      def squash_matchers(matchers) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        matchers = matchers.flat_map { |m| m.is_a?(LastMatch) ? m.matchers : m }
        unmatchable = matchers.include?(Unmatchable)
        matchers -= [Unmatchable]
        return [Unmatchable] if unmatchable && matchers.empty?

        implicit, ordered = matchers.partition(&:implicit?)

        ::Enumerator::Chain
          .new(implicit.sort { |a, b| a.squashable_with?(b) ? 0 : a.class.name <=> b.class.name }, ordered)
          .chunk_while { |a, b| a.squashable_with?(b) }.map do |chunk|
            next chunk.first if chunk.length == 1

            chunk.first.squash(chunk)
          end
      end
    end
  end
end
