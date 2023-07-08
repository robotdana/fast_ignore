# frozen_string_literal: true

class PathList
  # @api private
  class Matcher
    # @api private
    # Matches nothing
    Blank = Matcher.new

    # @api private
    def Blank.match(_)
      nil
    end

    # @api private
    def Blank.inspect
      'PathList::Matcher::Blank'
    end

    Blank.freeze
  end
end
