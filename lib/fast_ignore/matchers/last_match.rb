# frozen_string_literal: true

class FastIgnore
  module Matchers
    class LastMatch
      attr_reader :weight

      def initialize(matchers)
        @matchers = matchers
        @weight = @matchers.sum(&:weight)

        freeze
      end

      def empty?
        @weight.zero?
      end

      def match?(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match?(candidate)
          return val if val
        end

        false
      end
    end
  end
end
