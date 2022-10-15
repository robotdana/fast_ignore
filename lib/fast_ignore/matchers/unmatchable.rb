# frozen_string_literal: true

class FastIgnore
  module Matchers
    Unmatchable = Base.new

    class << Unmatchable
      def implicit?
        true
      end

      def inspect
        '#<FastIgnore::Matchers::Unmatchable>'
      end

      def match(_)
        nil
      end
    end

    Unmatchable.freeze
  end
end
