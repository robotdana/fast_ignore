# frozen_string_literal: true

class PathList
  module Matchers
    class Any < List
      def self.compress(matchers) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        matchers = super(matchers)
        return [Allow] if matchers.include?(Allow)

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

          matcher_set.first.squash(matcher_set.uniq.sort_by(&:weight))
        end.sort_by(&:weight)
      end

      def match(candidate)
        ignore = false

        @matchers.each do |m|
          case m.match(candidate)
          when :allow then return :allow
          when :ignore then ignore = true
          end
        end

        :ignore if ignore
      end

      private

      def calculate_weight
        super / 2.0
      end
    end
  end
end
