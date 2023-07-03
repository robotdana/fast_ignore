# frozen_string_literal: true

class PathList
  class Matcher
    class Any
      class Two < Any
        def self.build(matchers)
          Any.build(matchers)
        end

        def initialize(matchers)
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]

          super
        end

        def match(candidate)
          first_result = @matcher_a.match(candidate)
          return first_result if first_result == :allow

          @matcher_b.match(candidate) || first_result
        end

        attr_reader :polarity
      end
    end
  end
end
