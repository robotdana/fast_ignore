# frozen_string_literal: true

class FastIgnore
  class UnmatchableRule
    class << self
      def squash(_)
        self
      end

      def squashable_type
        5
      end

      def dir_only?
        false
      end

      def file_only?
        false
      end

      def shebang?
        false
      end

      # :nocov:
      def inspect
        '#<UnmatchableRule>'
      end
      # :nocov:

      def match?(_, _, _, _)
        false
      end
    end
  end
end
