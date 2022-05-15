# frozen_string_literal: true

class FastIgnore
  module Matchers
    class RuleGroup
      def initialize(matchers, allow, appendable: false)
        @matchers = matchers
        @allow = allow

        @matchers.freeze unless appendable

        freeze
      end

      def empty?
        return false unless @matchers.frozen?

        !@matchers || @matchers.empty? || @matchers.all?(&:empty?)
      end

      def weight
        @matchers.sum(&:weight)
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
