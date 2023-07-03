# frozen_string_literal: true

class PathList
  class Matcher
    Allow = Matcher.new

    def Allow.match(_)
      :allow
    end

    def Allow.inspect
      'PathList::Matcher::Allow'
    end

    def Allow.polarity
      :allow
    end

    Allow.freeze
  end
end
