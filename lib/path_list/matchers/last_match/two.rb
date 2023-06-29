# frozen_string_literal: true

class PathList
  module Matchers
    class LastMatch
      class Two < LastMatch
        def self.build(matchers)
          LastMatch.build(matchers)
        end

        def initialize(matchers) # rubocop:disable Lint/MissingSuper
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]
          @weight = calculate_weight
          @polarity = calculate_polarity

          freeze
        end

        def match(candidate)
          @matcher_b.match(candidate) || @matcher_a.match(candidate)
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
