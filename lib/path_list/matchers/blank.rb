# frozen_string_literal: true

class PathList
  module Matchers
    Blank = Base.new

    class << Blank
      def match(_)
        nil
      end

      def inspect
        'PathList::Matchers::Blank'
      end
    end

    Blank.freeze
  end
end
