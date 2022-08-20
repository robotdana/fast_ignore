# frozen_string_literal: true

class FastIgnore
  module Matchers
    class LastMatch
      attr_reader :weight

      def initialize(matchers)
        @matchers = squash_matchers(matchers)
        @weight = @matchers.sum(&:weight)

        freeze
      end

      def file_only?
        @matchers.all?(&:file_only?)
      end

      def dir_only?
        @matchers.all?(&:dir_only?)
      end

      def removable?
        @matchers.empty? || @matchers.all?(&:removable?)
      end

      def squashable_with?(other)
        other.instance_of?(LastMatch)
      end

      def squash(list)
        self.class.new(list.map(&:matchers))
      end

      def match(candidate)
        @matchers.each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        false
      end

      protected

      attr_reader :matchers

      private

      # TODO: these i should move maybe
      def squash_matchers(matchers)
        implicit, ordered = matchers.partition(&:implicit?)

        Enumerator::Chain
          .new(ordered.reverse, implicit.reverse_each.uniq)
          .chunk_while { |a, b| a.squashable_with?(b) }.map do |chunk|
            next chunk.first if chunk.length == 1

            chunk.first.squash(chunk)
          end
      end
    end
  end
end
