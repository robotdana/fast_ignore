# frozen_string_literal: true

class FastIgnore
  module Matchers
    class ShebangRegexp
      attr_reader :squash_id
      attr_reader :rule

      def initialize(rule, negation)
        @rule = rule
        @return_value = negation ? :allow : :ignore
        @squash_id = negation ? :allow_shebang : :ignore_shebang

        freeze
      end

      def squash(list)
        self.class.new(::Regexp.union(list.map(&:rule)), @return_value == :allow)
      end

      def file_only?
        true
      end

      def dir_only?
        false
      end

      # :nocov:
      def inspect
        "#<ShebangRegexp #{@return_value} /#{@rule.to_s[26..-4]}/>"
      end
      # :nocov:

      def match?(candidate)
        return false if candidate.filename.include?('.')

        @return_value if candidate.first_line&.match?(@rule)
      end

      def shebang?
        true
      end
    end
  end
end
