# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch
      class Two < LastMatch
        def self.build(matchers)
          LastMatch.build(matchers)
        end

        attr_reader :polarity
        attr_reader :weight

        def initialize(matchers) # rubocop:disable Lint/MissingSuper
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]
          @weight = calculate_weight
          @polarity = calculate_polarity

          freeze
        end

        def squashable_with?(_)
          false
        end

        def match(candidate)
          @matcher_b.match(candidate) || @matcher_a.match(candidate)
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
