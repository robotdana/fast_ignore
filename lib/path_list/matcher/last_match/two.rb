# frozen_string_literal: true

class PathList
  class Matcher
    class LastMatch
      # @api private
      class Two < LastMatch
        # @param (see LastMatch.build)
        # @return (see LastMatch.build)
        def self.build(matchers)
          LastMatch.build(matchers)
        end

        # @param (see LastMatch#initialize)
        def initialize(matchers)
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]

          super
        end

        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          @matcher_b.match(candidate) || @matcher_a.match(candidate)
        end

        # @return (see Matcher#polarity)
        attr_reader :polarity
      end
    end
  end
end
