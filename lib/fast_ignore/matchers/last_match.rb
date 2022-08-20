# frozen_string_literal: true

class FastIgnore
  module Matchers
    class LastMatch
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

        def squash_matchers(matchers)
          matchers -= [Unmatchable]
          implicit, ordered = matchers.partition(&:implicit?)

          Enumerator::Chain
            .new(ordered.reverse, implicit.reverse_each.uniq)
            .chunk_while { |a, b| a.squashable_with?(b) }.map do |chunk|
              next chunk.first if chunk.length == 1

              chunk.first.squash(chunk)
            end
        end
      end

      def initialize(matchers)
        @matchers = matchers

        freeze
      end

      def weight
        @matchers.sum(&:weight)
      end

      def file_only?
        # :nocov:
        # TODO: consistent api
        @matchers.all?(&:file_only?)
        # :nocov:
      end

      def dir_only?
        # :nocov:
        # TODO: consistent api
        @matchers.all?(&:dir_only?)
        # :nocov:
      end

      def removable?
        @matchers.empty? || @matchers.all?(&:removable?)
      end

      def implicit?
        @matchers.all?(&:implicit?)
      end

      def squashable_with?(_)
        # :nocov:
        # TODO: consistent api
        false
        # :nocov:
      end

      # def squash(list)
      #   self.class.build(list.flat_map { |l| l.matchers })
      # end

      def match(candidate)
        @matchers.each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        false
      end

      protected

      attr_reader :matchers
    end
  end
end
