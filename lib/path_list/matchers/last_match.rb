# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      def self.compress(matchers)
        super(matchers)
          .chunk_while { |a, b| a.polarity != :mixed && a.polarity == b.polarity }
          .flat_map { |chunk| Any.compress(chunk).reverse }
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
