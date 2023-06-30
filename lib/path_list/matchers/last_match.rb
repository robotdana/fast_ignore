# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      include Autoloader

      def self.compress(matchers) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        matchers = super(matchers)

        invalid = matchers.include?(Invalid)
        matchers -= [Invalid]
        return [Invalid] if matchers.empty? && invalid

        index = nil
        matchers = matchers[index..] if (index = matchers.rindex(Matchers::Allow))
        matchers = matchers[index..] if (index = matchers.rindex(Matchers::Ignore))

        matchers
          .chunk_while { |a, b| a.polarity != :mixed && a.polarity == b.polarity }
          .flat_map { |chunk| Any.compress(chunk).reverse }
          .chunk_while { |a, b| a.squashable_with?(b) }
          .map { |list| list.length == 1 ? list.first : list.first.squash(list, true) }
          .reverse
          .uniq
          .reverse
      end

      def match(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match(candidate)
          return val if val
        end

        nil
      end

      private

      def calculate_weight
        super / 2.0
      end
    end
  end
end
