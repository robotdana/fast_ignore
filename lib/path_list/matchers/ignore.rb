# frozen_string_literal: true

class PathList
  module Matchers
    Ignore = Base.new

    class << Ignore
      def match(_)
        :ignore
      end

      def inspect
        'PathList::Matchers::Ignore'
      end

      def polarity
        :ignore
      end
    end

    Ignore.freeze
  end
end
