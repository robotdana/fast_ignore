# frozen_string_literal: true

class PathList
  class Matcher
    class All
      # @api private
      class Ignore < All
        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          :ignore if @matchers.any? { |m| m.match(candidate) }
        end

        # @return (see Matcher#polarity)
        def polarity
          :ignore
        end
      end
    end
  end
end
