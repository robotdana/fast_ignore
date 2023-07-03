# frozen_string_literal: true

class PathList
  class Matcher
    class All
      class Two < All
        def self.build(matchers)
          All.build(matchers)
        end

        def initialize(matchers)
          @matcher_a = matchers[0]
          @matcher_b = matchers[1]

          super
        end

        def match(candidate)
          if ((result_a = @matcher_a.match(candidate)) == :allow || result_a.nil?) &&
              ((result_b = @matcher_b.match(candidate)) == :allow || result_b.nil?)
            result_a && result_b
          else
            :ignore
          end
        end

        attr_reader :polarity
      end
    end
  end
end
