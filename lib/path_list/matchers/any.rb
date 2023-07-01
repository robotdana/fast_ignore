# frozen_string_literal: true

class PathList
  module Matchers
    class Any < List
      include Autoloader

      attr_reader :matchers

      def self.compress(matchers)
        matchers = super(matchers)
        return [Matchers::Allow] if matchers.include?(Matchers::Allow)

        invalid = matchers.delete(Invalid)
        return [Invalid] if matchers.empty? && invalid

        squashable_sets = []

        matchers.each do |a_matcher|
          squashable_set = squashable_sets.find do |(b_matcher, *)|
            a_matcher.squashable_with?(b_matcher)
          end

          next squashable_set << a_matcher if squashable_set

          squashable_sets << [a_matcher]
        end

        squashable_sets.each.map do |matcher_set|
          next matcher_set.first if matcher_set.length == 1

          matcher_set.first.squash(matcher_set.uniq.sort_by(&:weight), false)
        end.sort_by(&:weight)
      end

      def match(candidate)
        default = nil

        @matchers.each do |m|
          if (result = m.match(candidate)) == :allow
            return :allow
          elsif result == :ignore
            default = :ignore
          end
        end

        default
      end

      private

      def calculate_weight
        super / 2.0
      end
    end
  end
end
