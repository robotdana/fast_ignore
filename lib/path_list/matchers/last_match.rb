# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      include Autoloader

      def self.compress(matchers)
        matchers = super(matchers)

        invalid = matchers.delete(Invalid)
        return [Invalid] if matchers.empty? && invalid

        index = nil
        matchers.slice!(0, index) if (index = matchers.rindex(Matchers::Allow))
        matchers.slice!(0, index) if (index = matchers.rindex(Matchers::Ignore))

        matchers = matchers
          .chunk_while { |a, b| a.polarity != :mixed && a.polarity == b.polarity }
          .flat_map { |chunk| Any.compress(chunk).reverse }
          .chunk_while { |a, b| a.squashable_with?(b) }
          .map { |list| list.length == 1 ? list.first : list.first.squash(list, true) }

        # this is to pass one test, maybe we don't need that test?
        matchers.reverse!
        matchers.uniq!
        matchers.reverse!

        matchers
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
