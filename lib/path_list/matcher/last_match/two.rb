# frozen_string_literal: true

class PathList
  class Matcher
    class LastMatch
      class Two < LastMatch
        def self.build(matchers)
          LastMatch.build(matchers)
        end

        def initialize(matchers)
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]

          super
        end

        def match(candidate)
          @matcher_b.match(candidate) || @matcher_a.match(candidate)
        end

        attr_reader :polarity
      end
    end
  end
end
