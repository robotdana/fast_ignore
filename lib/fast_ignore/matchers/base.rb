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

      def squashable_with?(other)
        self == other
      end

      def squash(_)
        self
      end

      def append(_)
        nil
      end

      def weight
        0
      end

      def removable?
        false
      end

      def match(_)
        nil
      end
    end
  end
end
