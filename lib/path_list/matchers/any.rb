# frozen_string_literal: true

class PathList
  module Matchers
    class Any < List
      def self.compress(matchers) # rubocop:disable Metrics/MethodLength
        matchers = super(matchers)
        return [Allow] if matchers.include?(Allow)

        squashable_sets = {}

        matchers.each do |a_matcher|
          _, s = squashable_sets.find do |(b_matcher, _)|
            a_matcher.squashable_with?(b_matcher)
          end

          next s << a_matcher if s

          squashable_sets[a_matcher] = [a_matcher]
        end

        squashable_sets.each_value.map do |matcher_set|
          next matcher_set.first if matcher_set.length == 1

          matcher_set.first.squash(matcher_set.sort_by(&:weight))
        end.sort_by(&:weight)
      end

      def match(candidate)
        ignore = false

        @matchers.each do |m|
          case m.match(candidate)
          when :allow then return :allow
          # :nocov:
          when :ignore then ignore = true
          when nil then nil
          end
        end

        :ignore if ignore
        # :nocov:
      end
    end
  end
end
