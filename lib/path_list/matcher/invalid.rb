# frozen_string_literal: true

class PathList
  class Matcher
    Invalid = Matcher.new

    def Invalid.match(_)
      nil
    end

    def Invalid.inspect
      'PathList::Matcher::Invalid'
    end

    Invalid.freeze
  end
end
