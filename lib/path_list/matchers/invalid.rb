# frozen_string_literal: true

class PathList
  module Matchers
    Invalid = Base.new

    class << Invalid
      def match(_)
        nil
      end

      def inspect
        'PathList::Matchers::Invalid'
      end
    end

    Invalid.freeze
  end
end
