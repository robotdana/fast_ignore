# frozen_string_literal: true

class PathList
  # @api private
  class Matcher
    # Matcher that allows everything
    # @api private
    Allow = Matcher.new

    # @api private
    def Allow.match(_)
      :allow
    end

    # @api private
    def Allow.inspect
      'PathList::Matcher::Allow'
    end

    # @api private
    def Allow.polarity
      :allow
    end

    Allow.freeze
  end
end
