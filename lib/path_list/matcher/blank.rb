# frozen_string_literal: true

class PathList
  class Matcher
    Blank = Matcher.new

    def Blank.match(_)
      nil
    end

    def Blank.inspect
      'PathList::Matcher::Blank'
    end

    Blank.freeze
  end
end
