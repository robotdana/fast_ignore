# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      def self.compress(matchers)
        super(matchers)
          .chunk_while { |a, b| a.polarity != :mixed && a.polarity == b.polarity }
          .map { |chunk| Any.build(chunk) }
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
