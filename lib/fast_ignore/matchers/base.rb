# frozen_string_literal: true

class FastIgnore
  module Matchers
    class Base
      def dir_only?
        false
      end

      def file_only?
        false
      end

      def implicit?
        false
      end

      def squashable_with?(_)
        # :nocov:
        false
        # :nocov:
      end

      def weight
        0
      end

      def removable?
        false
      end

      # :nocov:
      def inspect
        "#<#{self.class.name}>"
      end
      # :nocov:

      def match(_)
        nil
      end
    end
  end
end
