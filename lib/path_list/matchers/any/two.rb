# frozen_string_literal: true

class PathList
  module Matchers
    class Any
      class Two < Any
        def self.build(matchers)
          Any.build(matchers)
        end

        def initialize(matchers) # rubocop:disable Lint/MissingSuper
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]
          @weight = calculate_weight
          @polarity = calculate_polarity

          freeze
        end

        def match(candidate)
          first_result = @matcher_a.match(candidate)
          return first_result if first_result == :allow

          @matcher_b.match(candidate) || first_result
        end

        attr_reader :weight
        attr_reader :polarity

        def squashable_with?(_)
          false
        end

        def matchers
          [@matcher_a, @matcher_b]
        end
      end
    end
  end
end
