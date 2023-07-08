# frozen_string_literal: true

class PathList
  class Matcher
    class Any
      # @api private
      class Two < Any
        # @param (see Any.build)
        # @return (see Any.build)
        def self.build(matchers)
          Any.build(matchers)
        end

        # @param (see Any.build)
        def initialize(matchers)
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]

          super
        end

        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          first_result = @matcher_a.match(candidate)
          return first_result if first_result == :allow

          @matcher_b.match(candidate) || first_result
        end

        # @return (see Matcher#polarity)
        attr_reader :polarity
      end
    end
  end
end
