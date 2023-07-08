# frozen_string_literal: true

class PathList
  class Matcher
    class LastMatch
      # @api private
      class Ignore < LastMatch
        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          :ignore if @matchers.reverse_each.any? { |matcher| matcher.match(candidate) }
        end

        # @return (see Matcher#polarity)
        def polarity
          :ignore
        end
      end
    end
  end
end
