# frozen_string_literal: true

class FastIgnore
  module Matchers
    class WithinDir
      def initialize(matchers, root)
        @dir_matchers = squash_matchers(matchers.reject(&:file_only?))
        @file_matchers = squash_matchers(matchers.reject(&:dir_only?))
        @has_shebang_matchers = matchers.any?(&:shebang?)
        @root = root

        freeze
      end

      def match?(root_candidate)
        relative_candidate = root_candidate.relative_to(@root)
        return false unless relative_candidate

        (root_candidate.directory? ? @dir_matchers : @file_matchers).reverse_each do |rule|
          val = rule.match?(relative_candidate)
          return val if val
        end

        false
      end

      def empty?
        @dir_matchers.empty? && @file_matchers.empty?
      end

      def weight
        @dir_matchers.length + (@has_shebang_matchers ? 10 : 0)
      end

      private

      def squash_matchers(matchers)
        return matchers if matchers.empty?

        matchers -= [::FastIgnore::Matchers::Unmatchable]
        return [::FastIgnore::Matchers::Unmatchable] if matchers.empty?

        matchers.chunk_while { |a, b| a.squash_id == b.squash_id }.map do |chunk|
          next ::FastIgnore::Matchers::AllowAnyDir if chunk.include?(::FastIgnore::Matchers::AllowAnyDir)

          chunk.uniq!(&:rule)
          next chunk.first if chunk.length == 1

          chunk.first.squash(chunk)
        end
      end
    end
  end
end
