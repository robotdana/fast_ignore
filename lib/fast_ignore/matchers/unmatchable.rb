# frozen_string_literal: true

class FastIgnore
  module Matchers
    Unmatchable = Base.new

    class << Unmatchable
      def squash(_)
        # :nocov:
        self
        # :nocov:
      end

      def squashable_with?(other)
        # :nocov:
        self == other
        # :nocov:
      end

      def implicit?
        true
      end

      # :nocov:
      def inspect
        '#<Unmatchable>'
      end
      # :nocov:

      def match(_)
        nil
      end
    end
  end
end
