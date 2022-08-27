# frozen_string_literal: true

class FastIgnore
  module Matchers
    AllowAny = Base.new

    class << AllowAny
      def implicit?
        true
      end

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

      # :nocov:
      def inspect
        '#<FastIgnore::Matchers::AllowAny>'
      end
      # :nocov:

      def match(_)
        :allow
      end
    end
  end
end
