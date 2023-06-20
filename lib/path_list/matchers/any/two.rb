# frozen_string_literal: true

class PathList
  module Matchers
    class Any
      class Two < Any
        def self.build(matcher_a, matcher_b)
          Any.build([matcher_a, matcher_b])
        end

        attr_reader :polarity
        attr_reader :weight

        def initialize(matcher_a, matcher_b)
          @matcher_a = matcher_a
          @matcher_b = matcher_b
          @weight = calculate_weight
          @polarity = calculate_polarity
          # @matchers = [@matcher_a, @matcher_b]
        end

        def squashable_with?(_)
          false
        end

        def match(candidate)
          first_result = @matcher_a.match(candidate)
          return first_result if first_result == :allow

          @matcher_b.match(candidate) || first_result
        end

        def inspect
          "#{self.class}.new(\n#{matchers.map(&:inspect).join(",\n").gsub(/^/, '  ')}\n)"
        end

        def matchers
          [@matcher_a, @matcher_b]
        end

        private

        def calculate_weight
          (@matcher_a.weight + @matcher_b.weight) / 2.0
        end

        def calculate_polarity
          @matcher_a.polarity == @matcher_b.polarity ? @matcher_a.polarity : :mixed
        end
      end
    end
  end
end
