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

      def component_rules_count
        1
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

      def match?(_relative_path, _full_path, _filename, _content)
        false
      end
    end
  end
end
