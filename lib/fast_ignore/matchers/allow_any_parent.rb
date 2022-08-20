# frozen_string_literal: true

class FastIgnore
  module Matchers
    AllowAnyParent = Base.new

    class << AllowAnyParent
      def dir_only?
        true
      end

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
        '#<FastIgnore::Matchers::AllowAnyParent>'
      end
      # :nocov:

      def match(candidate)
        :allow if candidate.parent?
      end
    end
  end
end
