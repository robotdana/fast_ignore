# frozen_string_literal: true

class PathList
  class Matcher
    class All
      # @api private
      class Allow < All
        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          :allow if @matchers.all? { |m| m.match(candidate) }
        end

        # @return (see Matcher#polarity)
        def polarity
          :allow
        end
      end
    end
  end
end
