# frozen_string_literal: true

class FastIgnore
  module Matchers
    class WithinDir
      attr_reader :weight

      def initialize(matchers, root)
        @dir_matchers = squash_matchers(matchers.reject(&:file_only?))
        @file_matchers = squash_matchers(matchers.reject(&:dir_only?))
        @weight = matchers.sum(&:weight)
        @root = root

        freeze
      end

      def match?(candidate)
        relative_candidate = candidate.relative_to(@root)
        return false unless relative_candidate

        (candidate.directory? ? @dir_matchers : @file_matchers).reverse_each do |rule|
          val = rule.match?(relative_candidate)
          return val if val
        end

        false
      end

      private

      def squash_matchers(matchers)
        return matchers if matchers.empty?

        matchers -= [::FastIgnore::Matchers::Unmatchable]
        return [::FastIgnore::Matchers::Unmatchable] if matchers.empty?

        matchers.chunk_while { |a, b| a.squash_id == b.squash_id }.map do |chunk|
          next chunk.first if chunk.length == 1

          chunk.first.squash(chunk)
        end
      end
    end
  end
end
