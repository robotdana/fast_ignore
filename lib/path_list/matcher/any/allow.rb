# frozen_string_literal: true

class PathList
  class Matcher
    class Any
      # @api private
      class Allow < Any
        # @param (see Matcher#match)
        # @return (see Matcher#match)
        def match(candidate)
          :allow if @matchers.any? { |m| m.match(candidate) }
        end

        # @return (see Matcher#polarity)
        def polarity
          :allow
        end
      end
    end
  end
end
