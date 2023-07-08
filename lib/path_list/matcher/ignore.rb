# frozen_string_literal: true

class PathList
  # @api private
  class Matcher
    # Matcher that ignores everything
    # @api private
    Ignore = Matcher.new

    # @api private
    def Ignore.match(_)
      :ignore
    end

    # @api private
    def Ignore.inspect
      'PathList::Matcher::Ignore'
    end

    # @api private
    def Ignore.polarity
      :ignore
    end

    Ignore.freeze
  end
end
