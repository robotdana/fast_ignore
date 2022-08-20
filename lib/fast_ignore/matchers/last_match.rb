# frozen_string_literal: true

class FastIgnore
  module Matchers
    class LastMatch < List
      class << self
        def build(matchers)
          unmatchable = matchers.include?(Unmatchable)
          matchers = squash_matchers(matchers)
          case matchers.length
          when 0 then unmatchable ? new([Unmatchable]) : new(matchers)
          else new(matchers)
          end
        end

        private

        def squash_matchers(matchers) # rubocop:disable Metrics/AbcSize
          matchers -= [Unmatchable]
          implicit, ordered = matchers.partition(&:implicit?)

          Enumerator::Chain
            .new(ordered.reverse, implicit.sort { |a, b| a.squashable_with?(b) ? 0 : a.class.name <=> b.class.name })
            .chunk_while { |a, b| a.squashable_with?(b) }.map do |chunk|
              next chunk.first if chunk.length == 1

              chunk.first.squash(chunk)
            end
        end
      end

      def match(candidate)
        @matchers.each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        false
      end
    end
  end
end
