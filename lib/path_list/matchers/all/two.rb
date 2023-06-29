# frozen_string_literal: true

class PathList
  module Matchers
    class All
      class Two < All
        def self.build(matchers)
          All.build(matchers)
        end

        def initialize(matchers) # rubocop:disable Lint/MissingSuper
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]
          @weight = calculate_weight
          @polarity = calculate_polarity

          freeze
        end

        def match(candidate)
          if ((result_a = @matcher_a.match(candidate)) == :allow || result_a.nil?) &&
              ((result_b = @matcher_b.match(candidate)) == :allow || result_b.nil?)
            result_a && result_b
          else
            :ignore
          end
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
