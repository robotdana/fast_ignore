# frozen_string_literal: true

class PathList
  # @api private
  class Matcher
    # Matches nothing but isn't {Blank}
    # @api private
    Invalid = Matcher.new

    # @api private
    def Invalid.inspect
      'PathList::Matcher::Invalid'
    end

    Invalid.freeze
  end
end
