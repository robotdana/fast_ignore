# frozen_string_literal: true

class PathList
  module Matchers
    class CompressedLastMatch < LastMatch
      def self.compress(matchers)
        implicit, ordered = matchers.partition(&:implicit?)

        ordered = ordered
          .chunk_while { |a, b| a.polarity == b.polarity && a.polarity != :mixed }.map do |chunk|
            Any.build(chunk)
          end
        ordered.unshift(Any.build(implicit)) unless implicit.empty?

        ordered
      end
    end
  end
end
