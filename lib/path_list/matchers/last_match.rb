# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch < List
      def self.compress(matchers)
        implicit, ordered = matchers.partition(&:implicit?)

        ordered = ordered
          .chunk_while { |a, b| a.polarity == b.polarity && a.polarity != :mixed }.map do |chunk|
            Any.build(chunk)
          end
        ordered.unshift(Any.build(implicit)) unless implicit.empty?

        ordered
      end

      def initialize(matchers)
        @matchers = matchers

        freeze
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
