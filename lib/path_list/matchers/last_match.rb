# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      def self.build(matchers)
        matchers = matchers.flat_map { |m| m.is_a?(self) ? m.matchers : m }

        unmatchable = matchers.include?(Unmatchable)
        matchers -= [Unmatchable]
        matchers.reject!(&:removable?)

        matchers = compress(matchers)

        case matchers.length
        when 0 then unmatchable ? Unmatchable : new([])
        when 1 then matchers.first
        else new(matchers)
        end
      end

      def self.compress(matchers) # rubocop:disable Metrics/AbcSize
        implicit, ordered = matchers.partition(&:implicit?)

        ::Enumerator::Chain
          .new(implicit.sort { |a, b| a.squashable_with?(b) ? 0 : a.class.name <=> b.class.name }, ordered)
          .chunk_while { |a, b| a.squashable_with?(b) }.map do |chunk|
            next chunk.first if chunk.length == 1

            chunk.first.squash(chunk)
          end
      end

      def initialize(matchers)
        @matchers = matchers

        freeze
      end

      def match(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        nil
      end
    end
  end
end
