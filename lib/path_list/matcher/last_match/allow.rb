# frozen_string_literal: true

class PathList
  class Matcher
    class LastMatch
      # @api private
      class Allow < LastMatch
        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          :allow if @matchers.reverse_each.any? { |matcher| matcher.match(candidate) }
        end

        # @return (see Matcher#polarity)
        def polarity
          :allow
        end
      end
    end
  end
end
