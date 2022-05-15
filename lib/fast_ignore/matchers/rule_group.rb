# frozen_string_literal: true

class FastIgnore
  module Matchers
    class RuleGroup
      attr_reader :weight

      def initialize(matchers, allow)
        @matchers = matchers
        @allow = allow
        @weight = @matchers.sum(&:weight)

        freeze
      end

      def empty?
        @weight.zero?
      end

      def match?(candidate)
        @matchers.reverse_each do |matcher|
          val = matcher.match?(candidate)
          return val == :allow if val
        end

        not @allow
      end
    end
  end
end
