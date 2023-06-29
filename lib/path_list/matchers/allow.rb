# frozen_string_literal: true

class PathList
  module Matchers
    Allow = Base.new

    class << Allow
      def match(_)
        :allow
      end

      def inspect
        'PathList::Matchers::Allow'
      end

      def polarity
        :allow
      end
    end

    Allow.freeze
  end
end
