# frozen_string_literal: true

class PathList
  class Matcher
    Ignore = Matcher.new

    def Ignore.match(_)
      :ignore
    end

    def Ignore.inspect
      'PathList::Matcher::Ignore'
    end

    def Ignore.polarity
      :ignore
    end

    Ignore.freeze
  end
end
